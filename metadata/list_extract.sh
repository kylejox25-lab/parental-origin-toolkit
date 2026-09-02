#/bin/bash
awk -F ',' 'NR > 1 {
    gsub(/\r/, "", $NF)
    if ($NF == "1") print $1
}' k27_meta_data.csv > ../k27_list.txt
