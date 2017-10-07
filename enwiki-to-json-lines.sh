#!/bin/sh

wget -nv -O - ${WM}/${YEAR}${MONTH}/enwiki-${YEAR}${MONTH}-stub-meta-history${1}.xml.gz | gzip -cd | node node_modules/mediawiki-json-revisions/index.js | awk -f rpageid.awk > smh/${1}.json
