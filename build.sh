#!/bin/bash

YEAR=2017
MONTH=0901
WM="https://dumps.wikimedia.org/enwiki"
export LC_ALL=C

wget http://downloads.dbpedia.org/2016-10/core-i18n/en/geo_coordinates_en.tql.bz2
wget http://downloads.dbpedia.org/2016-10/core-i18n/en/page_ids_en.tql.bz2
./resource_coords-from-bz.sh < geo_coordinates_en.tql.bz2 | sort > coords.tsv
./resource_ids-from-bz.sh < page_ids_en.tql.bz2 | sort > ids.tsv
join ids.tsv coords.tsv | tr ' ' '\t' | cut -f 2,3,4 > page-coords.tsv
cut -f 1 < page-coords.tsv > page-ids.tsv
(echo 'create table page_coords (id integer primary key, lat real, lng real);' ; echo '.mode tabs'; echo '.import page-coords.tsv page_coords') | sqlite3 coords.db
(echo 'BEGIN {' ; cat page-ids.tsv | awk '{print "i[" $1 "]=1;"}' ; echo '} i[gensub(/.+"rpageid":"([^"]+)".+/,"\\1","g")]') > rpageid.awk

mkdir smh/
docker run -e MONTH=$MONTH -e YEAR=$YEAR -e WM=$WM -w /app -v $PWD:/app node:alpine sh -c 'apk add --no-cache ca-certificates wget git findutils; npm install git+https://git@github.com/lsb/mediawiki-json-revisions.git; seq 1 27 | xargs -P 27 -n 1 sh -c \'wget -O - ${WM}/${YEAR}${MONTH}/enwiki-${YEAR}${MONTH}-stub-meta-history${0}.xml.gz | gzip -cd | node node_modules/mediawiki-json-revisions/index.js | awk -f rpageid.awk > smh/${0}.json\''

docker run -e YEAR=$YEAR -v $PWD:/app -w /app lsb857/mathy-sqlite sh -c 'apk add --no-cache findutils gettext ; (echo "create table revisions (r text);" ; echo .mode tabs ; for f in smh/*.json ; do echo .import $f revisions ; done ; cat normalize-revisions.sql tfidf-cos-sqlite.sql) | sqlite3 revisions.db; seq 2001 $YEAR | xargs -P $(( YEAR - 2001 )) -n 1 sh -c \'PAGE_START=0 PAGE_END=1000000 YEAR=$0 envsubst < top-hundred.sql.envsubst | sqlite3 revisions.db > $0.psv\' ; for y in $(seq 2001 $YEAR); do echo .import $y.psv | sqlite3 revisions.db ; done'
