create table parsed_revisions (id integer primary key, time text, uid text, unm text, uip text, pageid text, pagetitle text);

insert into parsed_revisions select cast(json_extract(r,'$.rid') as integer),
                                    json_extract(r,'$.rtime'),
                                    json_extract(r, '$.ruid'), json_extract(r, '$.runm'), json_extract(r, '$.ruip'),
                                    json_extract(r, '$.rpageid'), json_extract(r, '$.rpagetitle') from revisions;

drop table revisions;

create table densepages (id integer primary key, pageid integer, pagetitle text);
insert into densepages (pageid, pagetitle) select pageid, pagetitle from parsed_revisions group by pageid, pagetitle order by count(*) desc;

create table densepage_coords (id integer primary key, lat real, lng real, title text);
insert into densepage_coords select d.id, lat, lng, pagetitle from densepages d join page_coords p on d.pageid = p.id;

create table users (id integer primary key, uid text, unm text, uip text);
insert into users (uid, unm, uip) select uid, unm, uip from parsed_revisions group by uid, unm, uip order by count(*) desc;
create index u on users(json_array(uid,unm,uip));

create table located_revisions (id integer primary key, epochsecond int, user_id int, page_id int);
insert into located_revisions select r.id, strftime('%s', time), u.id, dp.id
   from parsed_revisions r join users u on json_array(r.uid,r.unm,r.uip) = json_array(u.uid,u.unm,u.uip) join densepages dp using (pageid, pagetitle);

drop index u; drop table parsed_revisions; vacuum;
