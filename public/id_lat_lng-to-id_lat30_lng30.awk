BEGIN { FS="|" ; OFS="|" ; pi=3.14159265358979 ; z30 = 1024 * 1024 * 1024}
function tan(x) { return sin(x) / cos(x) }
function lng2tile30(lng) { return int(z30 * (lng+180)/360)}
function lat2tile30(lat) {return int((1 - log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) / pi) / 2 * z30)}
{print $1, lat2tile30($2), lng2tile30($3)}
