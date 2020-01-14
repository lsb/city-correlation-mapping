#!/bin/bash -ex
wget -r -l 1 --accept-regex=".*pages-articles-multistream.*xml-.*bz2" https://dumps.wikimedia.your.org/enwiki/$(date +%Y%m01)/
parallel '(bzcat {} | docker run -i --log-driver=none mediawiki-json-revisions | gzip > articles-{#}.json.gz) && rm {}' ::: dumps*/*/*/*.bz2
parallel 'zcat {} | jq -c "select(.rpagens == (0|tostring))" | docker run -i --log-driver=none mediawiki-json-coords | gzip > coords-articles-{#}.json.gz' ::: articles-*.json.gz
zcat coords-articles-*.json.gz | jq '{"key": .id, "value": true}' | jq -s from_entries > page-ids.json
seq 27 -1 1 | parallel --verbose 'zcat {}.json.gz | ./jq-prune.sh | gzip > pruned-{}.json.gz'
