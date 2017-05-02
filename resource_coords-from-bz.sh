bzip2 -cd /dev/stdin | sed -e 's/</ </g' | awk -v OFS="\t" '$2 == "<http://www.georss.org/georss/point>" { print $1, $3, $4 }' | sed -e 's/[.]$//' -e 's/"//g'
