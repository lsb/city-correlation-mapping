.mode tabs
create table resource_ids (resource text, id integer primary key);
.import ids.tsv resource_ids

create table resource_coords (resource text, lat real, lng real);
.import coords.tsv resource_coords

create table page_coords (id integer primary key, lat real, lng real);
insert into page_coords select id, lat, lng from resource_ids i join resource_coords c using (resource);

drop table resource_ids; drop table resource_coords;
