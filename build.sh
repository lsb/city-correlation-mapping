#!/bin/sh

MONTH=20170701
SHARD_COUNT=64
LC_ALL=C

wget http://downloads.dbpedia.org/2016-04/core-i18n/en/geo_coordinates_en.tql.bz2
wget http://downloads.dbpedia.org/2016-04/core-i18n/en/page_ids_en.tql.bz2
./resource_coords-from-bz.sh < geo_coordinates_en.tql.bz2 > coords.tsv
./resource_ids-from-bz.sh < page_ids_en.tql.bz2 > ids.tsv
sort < coords.tsv > coords.tsv-s
sort < ids.tsv > ids.tsv-s
join ids.tsv-s coords.tsv-s | tr ' ' '\t' | cut -f 2,3,4 > page-coords.tsv
cut -f 1 < page-coords.tsv > page-ids.tsv
(echo 'create table page_coords (id integer primary key, lat real, lng real);' ; echo '.mode tabs'; echo '.import page-coords.tsv page_coords') | sqlite3 coords.db
(echo 'BEGIN {' ; cat page-ids.tsv | awk '{print "i[" $1 "]=1;"}' ; echo '} i[gensub(/.+"rpageid":"([^"]+)".+/,"\\1","g")]') > rpageid.awk

mkdir smh/
docker run -e MONTH=$MONTH -w /app -v $PWD:/app node:alpine sh -c 'apk add --no-cache ca-certificates wget git sqlite ; npm install git+https://git@github.com/lsb/mediawiki-json-revisions.git ; for i in `seq 1 27` ; do wget -O - https://dumps.wikimedia.org/enwiki/${MONTH}/enwiki-${MONTH}-stub-meta-history${i}.xml.gz | gzip -cd | node node_modules/mediawiki-json-revisions/index.js | awk -f rpageid.awk | lzop -c > smh/${i}.lzop & done ; for i in `seq 1 27` ; do fg || true ; done ; sqlite3 revisions.db "create table revisions (r text)"; (echo .mode tabs; echo .import /dev/stdin revisions ; lzop -cd smh/*.lzop) | sqlite3 revisions.db'

docker run --rm -v "$PWD":/app -w /app lsb857/mathy-sqlite sh -c 'sqlite3 revisions.db < tfidf-cos-sqlite.sql'
docker run --rm -v "$PWD":/app -w /app -e SHARD_COUNT=$SHARD_COUNT lsb857/mathy-sqlite sh -c 'apk add --no-cache gettext ; for SHARD_ID in $(seq 0 $((SHARD_COUNT - 1))) ; do envsubst < top-hundred.sql.envsubst | sqlite3 revisions.db & done ; for i in $(seq 0 $SHARD_COUNT) ; do fg || true ; done'
