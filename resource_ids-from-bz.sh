bzip2 -cd /dev/stdin | grep -E '^<' | awk -v OFS="\t" '{print $1, $3}' | sed -E 's/"([0-9]+)"\^.+/\1/'
