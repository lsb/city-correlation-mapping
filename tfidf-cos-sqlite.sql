-- create table page_coords (id integer primary key, lat real, lng real); -- use import-coords.sql
-- revisions (id text pk, time text, text text, uid text, unm text, uip text, pageid text, pagetitle text, pagens text) --  use mediawiki-json-revisions

update revisions set id=json_extract(id,'$[0]'),
                     time=json_extract(time,'$[0]'),
                     uid=json_extract(uid,'$[0]'),
                     unm=json_extract(unm,'$[0]'),
                     uip=json_extract(uip,'$[0]'),
                     pageid=json_extract(pageid,'$[0]'),
                     pagetitle=json_extract(pagetitle,'$[0]');

create table pages (id integer primary key, title text);
insert into pages select distinct cast(pageid as integer), pagetitle from revisions;

create table users (id integer primary key, uid text, unm text, uip text);
insert into users (uid, unm, uip) select uid, unm, uip from revisions group by uid, unm, uip order by count(*) desc;

create table epochyears (epochyear integer primary key);
insert into epochyears select distinct strftime('%Y', time) from revisions;

-- analyze;

create table located_revisions (id integer primary key, epochsecond int, user_id int, page_id int);
insert into located_revisions select cast(r.id as integer), strftime('%s', time), u.id, p.id from revisions r join users u using (uid, unm, uip) join page_coords p on cast(r.pageid as integer) = p.id;

drop table revisions; vacuum; analyze;

create table term_frequency (user_id int, page_id int, epochyear int, c int); -- term = user, epochyear = high water mark for visibility
insert into term_frequency select user_id, page_id, epochyear, count(*) from located_revisions r join epochyears y on strftime('%Y', epochsecond, 'unixepoch') <= epochyear group by user_id, page_id, epochyear;

create table document_frequency (user_id int, epochyear int, c int); -- document = page
insert into document_frequency select user_id, epochyear, count(distinct page_id) from term_frequency group by user_id, epochyear;

create table user_relevance_to_page (user_id int, page_id int, epochyear int, tfidf real);
insert into user_relevance_to_page select user_id, page_id, epochyear, tf.c * 1.0 / df.c from term_frequency tf join document_frequency df using (user_id, epochyear) where df.c < 5000;

create table page_relevance (page_id int, epochyear int, magnitude real);
insert into page_relevance select page_id, epochyear, sqrt(sum(tfidf * tfidf)) from user_relevance_to_page group by page_id, epochyear;

create table user_relevance_to_page_magnitudes (user_id int, page_id int, epochyear int, tfidf real, magnitude real);
insert into user_relevance_to_page_magnitudes select user_id, page_id, epochyear, tfidf, magnitude from user_relevance_to_page join page_relevance using (page_id, epochyear);

create index i1 on user_relevance_to_page_magnitudes (epochyear, user_id, page_id, tfidf, magnitude);
create index i2 on user_relevance_to_page_magnitudes (epochyear, page_id, user_id, tfidf, magnitude);

create table top_hundred_interpage_similarities (page1_id integer, page2_id integer, epochyear integer, similarity double precision);


