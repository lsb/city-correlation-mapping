bzip2 -cd page_ids_en.nt.bz2 | grep -E '^<' | awk -v OFS="\t" '{print $1, $3}' | sed -E 's/"([0-9]+)"\^.+/\1/'
