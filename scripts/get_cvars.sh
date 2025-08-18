#!/bin/bash
set -euo pipefail

shortname="${1:?missing server shortname}"
ifs_backup=${IFS}

mkdir -p linuxgsm
cd linuxgsm || exit 1

wget -O linuxgsm.sh https://linuxgsm.sh
chmod +x linuxgsm.sh
bash linuxgsm.sh "${shortname}"

"./${shortname}server" auto-install
"./${shortname}server" start
sleep 10
"./${shortname}server" send cvarlist
sleep 10

echo "Display console log"
console_log="log/console/${shortname}server-console.log"
if [[ ! -s "${console_log}" ]]; then
  echo "The console log is empty"
else
  cat "${console_log}"
fi

out_file="../${shortname}-cvarlist.txt"
cp "${console_log}" "${out_file}" || true
"./${shortname}server" stop || true

echo "Removing all lines before 'cvar list'"
sed -ni -Ee '/cvar list/I,$ p' "${out_file}"

if grep -qi 'total[[:space:]]\+convars/concommands' "${out_file}"; then
  echo "Trimming lines after 'total convars/concommands' summary"
  sed -ni '1,/total[[:space:]]\+convars\/concommands/p' "${out_file}"
fi

# Whitespace normalization
sed -i 's/\r$//' "${out_file}"                           # strip CR
sed -i 's/[[:space:]]\+$//' "${out_file}"                 # strip trailing space
awk 'BEGIN{blank=0} { if ($0 ~ /^[ \t]*$/) { if (blank) next; blank=1; print "" } else { blank=0; print } }' \
  "${out_file}" > "${out_file}.tmp" && mv "${out_file}.tmp" "${out_file}"

final_file="${out_file}"
min_lines=20
min_cvar_lines=100

if [[ ! -s "${final_file}" ]]; then
  echo "Generated file is empty. Removing." >&2
  rm -f "${final_file}"; exit 1
fi

line_count=$(wc -l < "${final_file}")
cvar_line_count=$(grep -Eci '^[A-Za-z0-9_.]+[[:space:]]+:' "${final_file}" || true)
has_summary=0
grep -qi 'convars/concommands' "${final_file}" && has_summary=1 || true

echo "Validation stats: lines=${line_count} cvar_lines=${cvar_line_count} has_summary=${has_summary}" >&2

if (( line_count < min_lines )); then
  echo "Too few lines (${line_count} < ${min_lines}). Removing." >&2
  rm -f "${final_file}"; exit 1
fi

if (( has_summary == 0 )) && (( cvar_line_count < min_cvar_lines )); then
  echo "Incomplete dump (no summary & cvar_lines=${cvar_line_count} < ${min_cvar_lines}). Removing." >&2
  rm -f "${final_file}"; exit 1
fi

echo "Display cvarlist"
cat "${final_file}"

echo "Tidy"
cd .. || exit 1
rm -rf steamcmd linuxgsm || true

IFS=${ifs_backup}

