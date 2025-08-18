#!/bin/bash
set -euo pipefail
# Generate GitHub Actions matrix file from serverlist.csv
# Output: shortnamearray.json

out_file="shortnamearray.json"
: > "${out_file}"
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
  done < serverlist.csv
  echo -n ']}'
} >> "${out_file}"

# Validate JSON structure (basic)
if ! grep -q '"include":\[' "${out_file}"; then
  echo "Matrix generation failed" >&2
  exit 1
fi

echo "Generated matrix:"
cat "${out_file}" | sed 's/,/,&\n/g'
