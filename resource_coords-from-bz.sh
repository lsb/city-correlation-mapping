bzip2 -cd geo_coordinates_en.nt.bz2 | awk -v OFS="\t" '$2 == "<http://www.georss.org/georss/point>" { print $1, $3, $4 }' | sed -e 's/[.]$//' -e 's/"//g'
