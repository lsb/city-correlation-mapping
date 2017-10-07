.load math.so

create table similarities (page1_id integer, page2_id integer, primary key (page1_id, page2_id)) without rowid;
insert into similarities select page1_id, page2_id from top_twenty_interpage_similarities where epochyear = 2017;

.exit

create temporary table top_twenty_interpage_similarities_years(page1_id integer not null, page2_id integer not null, year_rollup integer not null, primary key(page1_id, page2_id)) without rowid;
insert into top_twenty_interpage_similarities_years select page1_id, page2_id, sum(cast(power(2, 2017-epochyear) as integer)) from top_twenty_interpage_similarities group by page1_id, page2_id;

create table year_rollups (id integer primary key, years integer);
insert into year_rollups (years) select year_rollup from top_twenty_interpage_similarities_years group by year_rollup order by count(*) desc;

update year_rollups set id = id-2; -- get more out of our 8-bit integers

create table top_twenty_interpage_similarities_yearids (page1_id integer not null, page2_id integer not null, year_rollup_id integer not null, primary key (page1_id, page2_id)) without rowid;
insert into top_twenty_interpage_similarities_yearids select page1_id, page2_id, id from top_twenty_interpage_similarities_years isy, year_rollups r where isy.year_rollup = r.years;
