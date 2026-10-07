#!/bin/bash
set -euo pipefail
# Generate GitHub Actions matrix file from serverlist.csv, or from the
# shortnames given as arguments (e.g. for a pull request dry run).
# Usage: generate-matrix.sh [shortname...]
# Output: shortnamearray.json

out_file="shortnamearray.json"

{
	echo -n '{"include":['
	first=1
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		shortname=${line%%,*}
		if [[ $first -eq 0 ]]; then
			echo -n ','
		fi
		first=0
		printf '{"shortname":"%s"}' "$shortname"
	done < <(if [[ $# -gt 0 ]]; then printf '%s\n' "$@"; else cat serverlist.csv; fi)
	echo ']}'
} > "${out_file}"

# Validate JSON structure
if ! python3 -m json.tool "${out_file}" > /dev/null 2>&1; then
	echo "Matrix generation failed: invalid JSON" >&2
	exit 1
fi

echo "Generated matrix:"
sed 's/,/,&\n/g' "${out_file}"
