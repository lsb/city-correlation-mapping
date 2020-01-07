zcat coords-articles-* | pigz > articles.json.gz
zcat {1..27}.json.gz | jq -c '{rpageid, rtime, ruser: (.runm + "/" + .ruid + "/" + .ruip)}' | pigz > revisions.json.gz
zcat revisions.json.gz | jq -c .rpageid | ./jq-histogram-by-frequency-descending.sh > page-densepage.json
zcat revisions.json.gz | jq -c .ruser | ./jq-histogram-by-frequency-descending.sh > user-denseuser.json
zcat revisions.json.gz | jq -c --slurpfile u user-denseuser.json --slurpfile p page-densepage.json '{page: $p[0][.rpageid], user: $u[0][.ruser], time: .rtime}' | pigz > dense-revisions.json.gz
zcat articles.json.gz | jq -c --slurpfile p page-densepage.json '{id: $p[0][.id], title, lat, lng}' | pigz > dense-articles.json.gz
