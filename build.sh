#!/bin/bash

mkdir smh/
for i in {1..27}
do
  wget -O smh/${i}.xml.gz https://dumps.wikimedia.org/enwiki/20161201/enwiki-20161201-stub-meta-history${i}.xml.gz
done

git clone https://github.com/lsb/parse-wikipedia-revisions.git

for i in {1..27}
do
  docker run --rm -v "$PWD"/parse-wikipedia-revisions:/app -v "$PWD"/smh:/smh -w /app clojure:alpine \
    sh -c "apk add --update sqlite && sqlite3 /smh/${i}.db < resources/schema.sql && gzip -cd /smh/${i}.xml.gz | lein run /dev/stdin /smh/${i}.db"
done # xargs it?

docker run --rm -v "$PWD"/smh:/smh -w /smh alpine \
  sh -c 'apk add --update sqlite && (echo "begin;" ; sqlite3 1.db .schema ; for d in *.db ; do sqlite3 ${d} .dump | grep -i insert ; done ; echo "commit;") | sqlite3 revisions.db'

wget http://downloads.dbpedia.org/2016-04/core-i18n/en/geo_coordinates_en.tql.bz2
wget http://downloads.dbpedia.org/2016-04/core-i18n/en/page_ids_en.tql.bz2

mv smh/revisions.db .

./resource_coords-from-bz.sh < geo_coordinates_en.tql.bz2 > coords.tsv
./resource_ids-from-bz.sh < page_ids_en.tql.bz2 > ids.tsv

docker run --rm -v "$PWD":/app -w /app alpine sh -c "apk add --update sqlite-dev musl-dev gcc && wget -O math.c 'http://www.sqlite.org/contrib/download/extension-functions.c?get=25' && gcc -g -fPIC -shared math.c -o /usr/lib/math.so && (echo .load math.so ; cat tfidf-cos-sqlite.sql) | sqlite3 revisions.db"
