-- set work_mem = 1000000; 

create table resource_ids (resource text, id int);
\copy resource_ids from '/mnt/resource_ids.tsv'

create table resource_coords (resource text, lat double precision, lng double precision);
\copy resource_coords from '/mnt/resource_coords.tsv'

create table revisions (id int, epochtime int, uname text, uid text, uip text, page_id int);
\copy revisions from program 'sed -e ''s:\\:\\\\:g'' /mnt/revisions.tsv'

create table page_coords (id int, lat double precision, lng double precision);
insert into page_coords select id, lat, lng from resource_ids i join resource_coords c using (resource);

create table users (id serial primary key, uname text, uid text, uip text);
insert into users (uname, uid, uip) select uname, uid, uip from revisions where page_id in (select id from page_coords) group by uname, uid, uip order by count(*) desc;

create table epochyears (epochtime int);
insert into epochyears select distinct t from (select extract(epoch from date_trunc('year', to_timestamp(epochtime)) + interval '1 year') as t from revisions offset 0) x;
—- offset 0 = force materialize. hashagg(seqscan) vs unique(sort)

create table located_revisions (id int, epochtime int, user_id int, page_id int);
insert into located_revisions select r.id, epochtime, u.id, page_id from revisions r join users u using (uname, uid, uip) join page_coords p on r.page_id = p.id;

create table term_frequency (user_id int, page_id int, epochyear int, c int);
insert into term_frequency select user_id, page_id, m.epochtime, count(*) from located_revisions r join epochyears m on r.epochtime < m.epochtime group by user_id, page_id, m.epochtime;

create table document_frequency (user_id int, epochyear int, c int);
insert into document_frequency select user_id, epochyear, count(distinct page_id) from term_frequency group by user_id, epochyear;

create table user_page_tfidf (user_id int, page_id int, epochyear int, tfidf double precision);
insert into user_page_tfidf select user_id, page_id, epochyear, tf.c * 1.0 / df.c from term_frequency tf join document_frequency df using (user_id, epochyear);

create table sparse_user_page_tfidf (user_id int, page_id int, epochyear int, tfidf double precision);
insert into sparse_user_page_tfidf select * from user_page_tfidf where user_id not in (select user_id from document_frequency where c > 5000);

create table sparse_page_tfidf_magnitudes (page_id int, epochyear int, magnitude double precision);
insert into sparse_page_tfidf_magnitudes select page_id, epochyear, sqrt(sum(tfidf * tfidf)) from sparse_user_page_tfidf group by page_id, epochyear;

create table sparse_tfidf_magnitudes (user_id int, page_id int, epochyear int, tfidf double precision, magnitude double precision);
insert into sparse_tfidf_magnitudes select user_id, page_id, epochyear, tfidf, magnitude from sparse_user_page_tfidf join sparse_page_tfidf_magnitudes using (page_id, epochyear);

create index on sparse_tfidf_magnitudes (epochyear, page_id); create index on sparse_tfidf_magnitudes (epochyear, user_id);

create table top_hundred_interpage_similarities (page1_id integer, page2_id integer, epochyear integer, similarity double precision);
create function top_hundred_similar(start_page_id int, start_epochyear int) returns setof top_hundred_interpage_similarities as $$
  select start_page_id, b.page_id, start_epochyear, -log(sum((a.tfidf * b.tfidf) / (a.magnitude * b.magnitude))) as similarity from
    sparse_tfidf_magnitudes a join sparse_tfidf_magnitudes b using (epochyear, user_id) where a.epochyear = start_epochyear and a.page_id = start_page_id group by b.page_id order by similarity limit 100
$$ language sql;
insert into top_hundred_interpage_similarities
  with pageyears as (select page_id, epochyear from sparse_tfidf_magnitudes order by epochyear, page_id)
    select tops.* from pageyears, lateral top_hundred_similar(pageyears.page_id, pageyears.epochyear) tops;
-- doing a window for row_number() and then a filter uses far more temp storage than we’d like, compared to (basically) a sub-select