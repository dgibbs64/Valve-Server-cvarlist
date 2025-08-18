#!/bin/bash
set -euo pipefail
shortname="${1}"
mkdir linuxgsm
cd linuxgsm || exit
wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh "${shortname}"

"./${shortname}server" auto-install
"./${shortname}server" start
sleep 10
"./${shortname}server" send cvarlist
sleep 10

echo "Display console log"
if [[ ! -s "log/console/${shortname}server-console.log" ]]; then
  echo "The console log is empty"
else
  cat "log/console/${shortname}server-console.log"
fi

cp "log/console/${shortname}server-console.log" ../"${shortname}-cvarlist.txt"
"./${shortname}server" stop

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

# Validation: ensure file is not empty and plausibly a full cvar dump
final_file="../${shortname}-cvarlist.txt"
min_lines=20       # absolute minimum to consider
min_cvar_lines=100 # heuristic: number of lines that look like cvar definitions

if [[ ! -s "${final_file}" ]]; then
  echo "Generated file is empty. Removing to avoid committing blank output." >&2
  rm -f "${final_file}"
  exit 1
fi

line_count=$(wc -l < "${final_file}")
# Count lines that look like: <token><spaces>: (case-insensitive)
cvar_line_count=$(grep -Eci '^[A-Za-z0-9_\.]+[[:space:]]+:' "${final_file}" || true)
has_summary=0
if grep -qi 'convars/concommands' "${final_file}"; then
  has_summary=1
fi

echo "Validation stats: lines=${line_count} cvar_lines=${cvar_line_count} has_summary=${has_summary}" >&2

if ((line_count < min_lines)); then
  echo "Generated file too small (lines=${line_count} < ${min_lines}). Removing." >&2
  rm -f "${final_file}"
  exit 1
fi

# Accept if summary present OR we have a large enough apparent cvar line count
if ((has_summary == 0)) && ((cvar_line_count < min_cvar_lines)); then
  echo "Generated file may be incomplete (no summary and cvar_lines=${cvar_line_count} < ${min_cvar_lines}). Removing." >&2
  rm -f "${final_file}"
  exit 1
fi

echo "Display cvarlist"
cat ../"${shortname}-cvarlist.txt"

echo "Tidy"
cd ../ || exit
rm -rf steamcmd
rm -rf linuxgsm
