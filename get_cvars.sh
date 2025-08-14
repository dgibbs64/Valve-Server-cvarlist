#!/bin/bash
shortname="${1}"
mkdir linuxgsm
cd linuxgsm || exit
wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh ${shortname}

./${shortname}server auto-install
./${shortname}server start
sleep 10
./${shortname}server send cvarlist
sleep 10

echo "Display console log"
if [[ ! -s "log/console/${shortname}server-console.log" ]]; then
	echo "The console log is empty"
else
	cat "log/console/${shortname}server-console.log"
fi

cp "log/console/${shortname}server-console.log" ../"${shortname}-cvarlist.txt"
./${shortname}server stop

# remove all lines before "cvar list"
echo "Removing all lines before \"cvar list\""
sed -ni -Ee '/cvar list/I,$ p' ../"${shortname}-cvarlist.txt"

# remove all lines after the summary line that contains "total convars/concommands"
# This keeps the line itself (e.g. "1247 total convars/concommands") but discards
# repeated shutdown/log spam that follows in some servers to keep files clean/reproducible.
if grep -qi 'total[[:space:]]\+convars/concommands' ../"${shortname}-cvarlist.txt"; then
	echo "Trimming lines after \"total convars/concommands\" summary"
	sed -ni '1,/total[[:space:]]\+convars\/concommands/p' ../"${shortname}-cvarlist.txt"
fi

# basic validation: ensure file is not empty and has a minimum number of lines / expected markers
final_file="../${shortname}-cvarlist.txt"
min_lines=20
if [[ ! -s "${final_file}" ]]; then
	echo "Generated file is empty. Removing to avoid committing blank output." >&2
	rm -f "${final_file}"
	exit 1
fi

line_count=$(wc -l < "${final_file}")
if (( line_count < min_lines )) || ! grep -qi 'convars/concommands' "${final_file}"; then
	echo "Generated file appears incomplete (lines=${line_count}). Removing to avoid committing partial output." >&2
	rm -f "${final_file}"
	exit 1
fi

echo "Display cvarlist"
cat ../"${shortname}-cvarlist.txt"

echo "Tidy"
cd ../ || exit
rm -rf steamcmd
rm -rf linuxgsm
