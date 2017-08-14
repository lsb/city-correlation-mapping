.load math.so

create table epochyears (epochyear integer primary key);
insert into epochyears select distinct strftime('%Y', epochsecond, 'unixepoch') from located_revisions;

create table term_frequency (user_id int, page_id int, epochyear int, c int, primary key (epochyear, user_id, page_id)) without rowid; -- term = user, epochyear = high water mark for visibility
insert into term_frequency select user_id, page_id, epochyear, count(*) from located_revisions r join epochyears y on strftime('%Y', epochsecond, 'unixepoch') <= epochyear group by epochyear, user_id, page_id;

create table document_frequency (user_id int, epochyear int, c int, primary key (epochyear, user_id)) without rowid; -- document = page
insert into document_frequency select user_id, epochyear, count(distinct page_id) from term_frequency group by epochyear, user_id;

create table user_relevance_to_page (user_id int, page_id int, epochyear int, tfidf real, primary key (epochyear, page_id, user_id)) without rowid;
insert into user_relevance_to_page select user_id, page_id, epochyear, tf.c * 1.0 / df.c from term_frequency tf join document_frequency df using (epochyear, user_id) where df.c < 1000;

create table page_relevance (page_id int, epochyear int, magnitude real, primary key (epochyear, page_id)) without rowid;
insert into page_relevance select page_id, epochyear, sqrt(sum(tfidf * tfidf)) from user_relevance_to_page group by epochyear, page_id;

create table user_relevance_to_page_magnitudes (user_id int, page_id int, epochyear int, tfidf real, magnitude real, primary key (epochyear, user_id, page_id)) without rowid;
insert into user_relevance_to_page_magnitudes select user_id, page_id, epochyear, tfidf, magnitude from user_relevance_to_page join page_relevance using (epochyear, page_id);

create index urpm_epu on user_relevance_to_page_magnitudes (epochyear, page_id, user_id, tfidf, magnitude);

analyze;

create table top_hundred_interpage_similarities (page1_id integer, page2_id integer, epochyear integer, similarity double precision, primary key (epochyear, page1_id, page2_id)) without rowid;
