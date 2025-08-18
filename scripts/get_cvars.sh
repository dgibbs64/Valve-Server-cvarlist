#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--docker] <shortname>" >&2
  exit 1
}

use_docker=${USE_DOCKER:-0}
args=()
for arg in "$@"; do
  case "$arg" in
    --docker) use_docker=1 ;;
    -h|--help) usage ;;
    *) args+=("$arg") ;;
  esac
done

if ((${#args[@]} != 1)); then
  usage
fi

shortname="${args[0]}"
ifs_backup=${IFS}

out_file="${shortname}-cvarlist.txt"

run_docker() {
  local image_prefix=${DOCKER_IMAGE_PREFIX:-gameservermanagers/gameserver}
  local image="${image_prefix}:${shortname}"
  local cname="cvar-${shortname}-$$"
  echo "[docker] Pulling image ${image}" >&2
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker not available; aborting docker path" >&2
    return 1
  fi
  docker pull "${image}" || return 1
  echo "[docker] Starting container ${cname}" >&2
  docker run -d --name "${cname}" --rm "${image}" >/dev/null
  # Wait a bit for server to init
  attempts=30
  while (( attempts > 0 )); do
    if docker logs "${cname}" 2>&1 | grep -qi "cvar"; then
      break
    fi
    attempts=$((attempts-1))
    sleep 5
  done
  echo "[docker] Sending cvarlist command" >&2
  # Attempt to send cvarlist; ignore failures
  docker exec "${cname}" bash -lc "./${shortname}server send cvarlist" 2>/dev/null || true
  sleep 10
  echo "[docker] Collecting logs" >&2
  docker logs "${cname}" > "${out_file}.raw" 2>/dev/null || true
  # Stop container
  docker rm -f "${cname}" >/dev/null 2>&1 || true
  # Extract just the console region similar to non-docker path
  cp "${out_file}.raw" "${out_file}" || true
}

if (( use_docker == 1 )); then
  if run_docker; then
    echo "Docker path succeeded" >&2
  else
    echo "Docker path failed; falling back to native LinuxGSM install" >&2
  fi
fi

if [[ ! -s "${out_file}" ]]; then
  # Proceed with native LinuxGSM install (legacy path)
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

  cp "${console_log}" "../${out_file}" || true
  "./${shortname}server" stop || true

  echo "Removing all lines before 'cvar list'"
  cd .. || exit 1
fi
sed -ni -Ee '/cvar list/I,$ p' "${out_file}"

if grep -qi 'total[[:space:]]\+convars/concommands' "${out_file}"; then
  echo "Trimming lines after 'total convars/concommands' summary"
  sed -ni '1,/total[[:space:]]\+convars\/concommands/p' "${out_file}"
fi

# Whitespace normalization
sed -i 's/\r$//' "${out_file}"            # strip CR
sed -i 's/[[:space:]]\+$//' "${out_file}" # strip trailing space
awk 'BEGIN{blank=0} { if ($0 ~ /^[ \t]*$/) { if (blank) next; blank=1; print "" } else { blank=0; print } }' \
  "${out_file}" > "${out_file}.tmp" && mv "${out_file}.tmp" "${out_file}"

final_file="${out_file}"
min_lines=20
min_cvar_lines=100

if [[ ! -s "${final_file}" ]]; then
  echo "Generated file is empty. Removing." >&2
  rm -f "${final_file}"
  exit 1
fi

line_count=$(wc -l < "${final_file}")
cvar_line_count=$(grep -Eci '^[A-Za-z0-9_.]+[[:space:]]+:' "${final_file}" || true)
has_summary=0
grep -qi 'convars/concommands' "${final_file}" && has_summary=1 || true

echo "Validation stats: lines=${line_count} cvar_lines=${cvar_line_count} has_summary=${has_summary}" >&2

if ((line_count < min_lines)); then
  echo "Too few lines (${line_count} < ${min_lines}). Removing." >&2
  rm -f "${final_file}"
  exit 1
fi

if ((has_summary == 0)) && ((cvar_line_count < min_cvar_lines)); then
  echo "Incomplete dump (no summary & cvar_lines=${cvar_line_count} < ${min_cvar_lines}). Removing." >&2
  rm -f "${final_file}"
  exit 1
fi

echo "Display cvarlist"
cat "${final_file}"

if [[ -d linuxgsm ]]; then
  echo "Tidy"
  rm -rf steamcmd linuxgsm || true
fi

IFS=${ifs_backup}
