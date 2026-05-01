#!/bin/bash
set -euo pipefail

shortname="${1:?missing server shortname}"
orig_dir="$(pwd)"
container_name="${shortname}server_cvarlist"
data_dir=""

cleanup() {
	docker stop "${container_name}" 2>/dev/null || true
	docker rm "${container_name}" 2>/dev/null || true
	if [[ -n "${data_dir}" ]]; then
		rm -rf "${data_dir}" 2>/dev/null || true
	fi
}
trap cleanup EXIT

image="ghcr.io/gameservermanagers/gameserver:${shortname}"

echo "Pulling image ${image}..."
docker pull "${image}"

data_dir=$(mktemp -d)

# Pre-create steam credentials config if provided via environment
if [[ -n "${STEAMCMD_USER:-}" ]]; then
	instance="${shortname}server"
	mkdir -p "${data_dir}/lgsm/config-lgsm/${instance}"
	{
		printf 'steamuser="%s"\n' "${STEAMCMD_USER}"
		printf 'steampass="%s"\n' "${STEAMCMD_PASS:-}"
	} > "${data_dir}/lgsm/config-lgsm/${instance}/common.cfg"
fi

# Run container — it auto-installs and auto-starts the game server
echo "Starting container ${container_name}..."
docker run -d \
	--name "${container_name}" \
	-v "${data_dir}:/data" \
	"${image}"

# Poll until the server reports online (auto-install can take a long time)
echo "Waiting for server to come online..."
max_wait=2400 # 40 minutes
elapsed=0
interval=30
server_online=0
while [[ ${elapsed} -lt ${max_wait} ]]; do
	if docker exec --user linuxgsm "${container_name}" "./${shortname}server" status 2>/dev/null | grep -qi "online"; then
		echo "Server is online"
		server_online=1
		break
	fi
	echo "  Server not ready yet (${elapsed}s elapsed)..."
	sleep "${interval}"
	elapsed=$((elapsed + interval))
done

if [[ ${server_online} -eq 0 ]]; then
	echo "Timeout: server did not come online after ${max_wait}s" >&2
	exit 1
fi

# Send the cvarlist command via the LinuxGSM console
echo "Sending cvarlist command..."
docker exec --user linuxgsm "${container_name}" "./${shortname}server" send cvarlist
sleep 10

echo "Display console log"
console_log="${data_dir}/log/console/${shortname}server-console.log"
if [[ ! -s "${console_log}" ]]; then
	echo "The console log is empty or missing" >&2
	exit 1
fi
cat "${console_log}"

out_file="${orig_dir}/${shortname}-cvarlist.txt"
cp "${console_log}" "${out_file}"

echo "Removing all lines before 'cvar list'"
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
# ensure final newline
tail -c1 "${out_file}" | od -c | grep -q '\\n' || printf '\n' >> "${out_file}"

min_lines=20
min_cvar_lines=100

if [[ ! -s "${out_file}" ]]; then
	echo "Generated file is empty. Removing." >&2
	rm -f "${out_file}"
	exit 1
fi

line_count=$(wc -l < "${out_file}")
cvar_line_count=$(grep -Eci '^[A-Za-z0-9_.]+[[:space:]]+:' "${out_file}" || true)
has_summary=0
grep -qi 'convars/concommands' "${out_file}" && has_summary=1 || true

echo "Validation stats: lines=${line_count} cvar_lines=${cvar_line_count} has_summary=${has_summary}" >&2

if ((line_count < min_lines)); then
	echo "Too few lines (${line_count} < ${min_lines}). Removing." >&2
	rm -f "${out_file}"
	exit 1
fi

if ((has_summary == 0)) && ((cvar_line_count < min_cvar_lines)); then
	echo "Incomplete dump (no summary & cvar_lines=${cvar_line_count} < ${min_cvar_lines}). Removing." >&2
	rm -f "${out_file}"
	exit 1
fi

echo "Display cvarlist"
cat "${out_file}"
