#!/bin/bash
echo -n "{" > "shortnamearray.json"
echo -n "\"include\":[" >> "shortnamearray.json"

while read -r line; do
	shortname=$(echo "$line" | awk -F, '{ print $1 }')
	export shortname
	echo -n "{" >> "shortnamearray.json"
	echo -n "\"shortname\":" >> "shortnamearray.json"
	echo -n "\"${shortname}\"" >> "shortnamearray.json"
	echo -n "}," >> "shortnamearray.json"
done < <(tail ../../serverlist.csv)
sed -i '$ s/.$//' "shortnamearray.json"
echo -n "]" >> "shortnamearray.json"
echo -n "}" >> "shortnamearray.json"
