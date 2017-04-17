#!/bin/bash

mkdir smh/
for i in {1..27}
do
  wget -O - https://dumps.wikimedia.org/enwiki/20170401/enwiki-20170401-stub-meta-history${i}.xml.gz | gzip -cd | docker run --rm -i lsb857/mediawiki-json-revisions | gzip -c1 > smh/${i}.tsv.gz
done

wget http://downloads.dbpedia.org/2016-04/core-i18n/en/geo_coordinates_en.tql.bz2
wget http://downloads.dbpedia.org/2016-04/core-i18n/en/page_ids_en.tql.bz2
./resource_coords-from-bz.sh < geo_coordinates_en.tql.bz2 > coords.tsv
./resource_ids-from-bz.sh < page_ids_en.tql.bz2 > ids.tsv
docker run --rm -v "$PWD":/app -w /app lsb857/mathy-sqlite sh -c 'sqlite3 coords.db < import-coords.sql'

for i in {1..27}
do
  gzip -vd smh/${i}.tsv.gz
  docker run --rm -v "$PWD":/app -w /app lsb857/mathy-sqlite sqlite3 smh/${i}.db "CREATE TABLE revisions (id text primary key, time text, text text, uid text, unm text, uip text, pageid text, pagetitle text, ns text);"
  docker run --rm -v "$PWD":/app -w /app lsb857/mathy-sqlite sh -c "(echo .mode tabs ; echo .import 'smh/${i}.tsv' revisions) | sqlite3 smh/${i}.db"
  docker run --rm -v "$PWD":/app -w /app lsb857/mathy-sqlite sqlite3 smh/${i}.db "attach 'coords.db' as coords; delete from revisions where cast(json_extract(pageid, '\$[0]') as integer) not in (select id from page_coords); vacuum;"
  rm smh/${i}.tsv
done

docker run --rm -v "$PWD":/app -w /app lsb857/mathy-sqlite \
  sh -c '(sqlite3 coords.db .dump ; echo "begin;" ; sqlite3 smh/1.db .schema ; for d in smh/*.db ; do sqlite3 ${d} .dump | grep -i insert ; done ; echo "commit;") | sqlite3 revisions.db'


docker run --rm -v "$PWD":/app -w /app lsb857/mathy-sqlite sh -c "sqlite3 revisions.db < tfidf-cos-sqlite.sql"
SHARD_COUNT=64
for SHARD_ID in $(seq 0 $((SHARD_COUNT - 1)))
do
    docker run --rm -v "$PWD":/app -w /app -e "SHARD_COUNT=$SHARD_COUNT" -e "SHARD_ID=$SHARD_ID" lsb857/mathy-sqlite sh -c "apk add --no-cache gettext && envsubst < top-hundred.sql.envsubst | sqlite3 revisions.db" &
done

