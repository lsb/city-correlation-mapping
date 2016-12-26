pragma cache_size = 10000000;

.mode tabs
create table resource_ids (resource text, id integer primary key);
.import ids.tsv resource_ids

create table resource_coords (resource text, lat real, lng real);
.import coords.tsv resource_coords

-- create table revisions (id integer primary key, epochtime int, user text, page_id int, page_title text); -- use parse-wikipedia-revisions to get this from the stub-meta-history

create table pages (id integer primary key, title text);
insert into pages select distinct page_id, page_title from revisions;

create table page_coords (id integer primary key, lat real, lng real);
insert into page_coords select id, lat, lng from resource_ids i join resource_coords c using (resource);

drop table resource_ids; drop table resource_coords;

create table users (id integer primary key, user text);
insert into users (user) select user from revisions join page_coords on page_id = page_coords.id group by user order by count(*) desc;

create table epochyears (epochyear integer primary key);
insert into epochyears select distinct strftime("%Y", epochsecond, "unixepoch") from revisions;

-- analyze;

create table located_revisions (id integer primary key, epochsecond int, user_id int, page_id int);
insert into located_revisions select r.id, epochsecond, u.id, page_id from revisions r join users u using (user) join page_coords p on r.page_id = p.id;

drop table revisions; vacuum; analyze;

create table term_frequency (user_id int, page_id int, epochyear int, c int); -- term = user, epochyear = high water mark for visibility
insert into term_frequency select user_id, page_id, epochyear, count(*) from located_revisions r join epochyears y on strftime("%Y", epochsecond, "unixepoch") <= epochyear group by user_id, page_id, epochyear;

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

create table top_twenty_interpage_similarities_json (page1_id integer, epochyear integer, similarities json);
insert into top_twenty_interpage_similarities_json
  select p.id, y.epochyear, json_group_array(
    select json_object(page2_id, similarity) from
      (
        select b.page_id as page2_id, -log(sum((a.tfidf * b.tfidf) / (a.magnitude * b.magnitude))) as similarity
          from user_relevance_to_page_magnitudes a join user_relevance_to_page_magnitudes b using (epochyear, user_id)
        where a.page_id = p.id and a.epochyear = y.epochyear and b.page_id != a.page_id
        group by b.page_id order by similarity limit 20
      )
  ) from page_coords p, epochyears y;

create table top_twenty_interpage_similarities (page1_id integer, page2_id integer, epochyear integer, similarity double precision);

insert into top_twenty_interpage_similarities
  select page1_id, epochyear, json_each.key, json_each.value from
    (select page1_id, epochyear, json_each.value from top_twenty_interpage_similarities_json, json_each(similarities)) t, json_each(t.value);
-- (def pages (map :id (clojure.java.jdbc/query ... ["select id from page_coords"])))
-- (def epochyears (map :epochyear (clojure.java.jdbc/query ... ["select epochyear from epochyears"])))
-- (for [y epochyears] (clojure.java.jdbc/with-db-transaction [txn ...] (doall (for [p pages] (clojure.java.jdbc/execute! txn ["insert into top_twenty_interpage_similarities select a.page_id, b.page_id, epochyear, -log(sum((a.tfidf * b.tfidf) / (a.magnitude * b.magnitude))) similarity from user_relevance_to_page_magnitudes a join user_relevance_to_page_magnitudes b using (epochyear, user_id) where a.page_id = ? and epochyear = ? and b.page_id != a.page_id group by b.page_id order by similarity limit 20" p y]))) nil))


