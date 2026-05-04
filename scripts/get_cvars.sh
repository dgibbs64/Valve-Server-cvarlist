#!/bin/bash
set -euo pipefail

shortname="${1:?missing server shortname}"
orig_dir="$(pwd)"
container_name="${shortname}server_cvarlist"
data_dir=""
steam_user="${STEAMCMD_USER:-anonymous}"
steam_pass="${STEAMCMD_PASS:-}"

skip() {
	echo "Skipping ${shortname}: $*" >&2
	exit 0
}

cleanup() {
	docker stop "${container_name}" 2> /dev/null || true
	docker rm "${container_name}" 2> /dev/null || true
	if [[ -n "${data_dir}" ]]; then
		rm -rf "${data_dir}" 2> /dev/null || true
	fi
}
trap cleanup EXIT

image="ghcr.io/gameservermanagers/gameserver:${shortname}"

echo "Pulling image ${image}..."
docker pull "${image}"

data_dir=$(mktemp -d)

# Always provide Steam config. Most titles can install with anonymous login.
instance="${shortname}server"
mkdir -p "${data_dir}/lgsm/config-lgsm/${instance}"
mkdir -p "${data_dir}/lgsm/config-lgsm"
{
	printf 'steamuser="%s"\n' "${steam_user}"
	printf 'steampass="%s"\n' "${steam_pass}"
} > "${data_dir}/lgsm/config-lgsm/${instance}/common.cfg"
{
	printf 'steamuser="%s"\n' "${steam_user}"
	printf 'steampass="%s"\n' "${steam_pass}"
} > "${data_dir}/lgsm/config-lgsm/common.cfg"

# Run container — it auto-installs and auto-starts the game server
echo "Starting container ${container_name}..."
docker_run_args=(
	-d
	--name "${container_name}"
	-v "${data_dir}:/data"
)

docker_run_args+=(
	-e "STEAMCMD_USER=${steam_user}"
	-e "STEAMCMD_PASS=${steam_pass}"
)

docker run "${docker_run_args[@]}" "${image}"

# Checks container logs for fatal install/start errors; exits with a clear message if found.
check_for_fatal_errors() {
	local logs
	logs=$(docker logs "${container_name}" 2>&1)
	if echo "${logs}" | grep -q "Missing configuration"; then
		echo "ERROR: SteamCMD requires Steam credentials for ${shortname}." >&2
		echo "  Set STEAMCMD_USER and STEAMCMD_PASS in .secrets (or as environment variables)." >&2
		exit 1
	elif echo "${logs}" | grep -q "No subscription"; then
		echo "ERROR: Steam account does not have access to the ${shortname} server app." >&2
		exit 1
	elif echo "${logs}" | grep -qE "Error! Installing|FAIL: Executable was not found"; then
		echo "ERROR: Server installation failed for ${shortname}. Last container output:" >&2
		echo "${logs}" | tail -20 >&2
		exit 1
	fi
}

find_cvar_output_log() {
	local candidate
	while IFS= read -r candidate; do
		[[ -s "${candidate}" ]] || continue
		if grep -qiE 'cvar list|convars/concommands' "${candidate}"; then
			echo "${candidate}"
			return 0
		fi
	done < <(find "${data_dir}" -type f \( -name '*console*.log' -o -name '*.log' -o -name '*.txt' \) -size +0c 2> /dev/null)
	return 1
}

# Poll until the entrypoint prints "Tail log files", which is emitted by
# entrypoint-user.sh immediately after the game server has been started,
# regardless of game type. Auto-install can take a long time.
echo "Waiting for server to come online..."
max_wait="${MAX_WAIT_SECONDS:-2400}" # default 40 minutes
elapsed=0
interval=30
server_online=0
echo "Wait budget: max_wait=${max_wait}s interval=${interval}s"
while [[ ${elapsed} -lt ${max_wait} ]]; do
	if docker logs "${container_name}" 2>&1 | grep -q "Tail log files"; then
		echo "Server is online"
		server_online=1
		break
	fi
	# If the container has already exited, there's no point waiting further
	container_status=$(docker inspect --format '{{.State.Status}}' "${container_name}" 2> /dev/null || echo "missing")
	if [[ "${container_status}" != "running" ]]; then
		check_for_fatal_errors
		echo "Container exited unexpectedly (status: ${container_status}). Last output:" >&2
		docker logs --tail 20 "${container_name}" 2>&1 >&2
		exit 1
	fi
	check_for_fatal_errors
	echo "  Server not ready yet (${elapsed}s elapsed)... Last container output:"
	docker logs --tail 5 "${container_name}" 2>&1 | sed 's/^/    /'
	sleep "${interval}"
	elapsed=$((elapsed + interval))
done

if [[ ${server_online} -eq 0 ]]; then
	echo "Timeout: server did not come online after ${max_wait}s" >&2
	exit 1
fi

# Phase 2: wait for the console log to have content, confirming the game
# server process is actually running and not just launched by LinuxGSM.
echo "Waiting for console log to have content..."
console_log="${data_dir}/log/console/${shortname}server-console.log"
discovered_log=""
console_wait="${CONSOLE_WAIT_SECONDS:-600}" # default 10 minutes
console_elapsed=0
console_interval=15
echo "Console wait budget: console_wait=${console_wait}s interval=${console_interval}s"
while [[ ${console_elapsed} -lt ${console_wait} ]]; do
	if [[ -s "${console_log}" ]]; then
		echo "Console log has content — server is ready"
		break
	fi
	# Some containerized servers fail LinuxGSM self-query checks despite being usable.
	# If startup progressed enough, try sending cvarlist early rather than waiting out the full timeout.
	if ((console_elapsed >= 90)); then
		break
	fi
	if discovered_log=$(find_cvar_output_log); then
		console_log="${discovered_log}"
		echo "Detected log with cvar output: ${console_log}"
		break
	fi
	check_for_fatal_errors
	echo "  Waiting for console log... (${console_elapsed}s elapsed)... Last container output:"
	docker logs --tail 5 "${container_name}" 2>&1 | sed 's/^/    /'
	sleep "${console_interval}"
	console_elapsed=$((console_elapsed + console_interval))
done

# Send the cvarlist command via the LinuxGSM console
echo "Sending cvarlist command..."
send_attempts=5
send_ok=0
for attempt in $(seq 1 "${send_attempts}"); do
	if docker exec --user linuxgsm "${container_name}" "./${shortname}server" send cvarlist; then
		send_ok=1
		sleep 12
		if [[ -s "${console_log}" ]] && grep -qi 'cvar list' "${console_log}"; then
			break
		fi
		if discovered_log=$(find_cvar_output_log); then
			console_log="${discovered_log}"
			echo "Detected log with cvar output: ${console_log}"
			break
		fi
	fi
	echo "  cvarlist send attempt ${attempt}/${send_attempts} did not produce output yet; retrying..."
	sleep 8
done

if [[ ${send_ok} -eq 0 ]]; then
	skip "failed to send cvarlist command"
fi

echo "Display console log"
if [[ -s "${console_log}" ]]; then
	cat "${console_log}"
else
	echo "Console log path not found yet; continuing with fallback extraction"
fi

out_file="${orig_dir}/${shortname}-cvarlist.txt"
if [[ -s "${console_log}" ]]; then
	cp "${console_log}" "${out_file}"
else
	echo "Console log path not found; falling back to container logs"
	docker logs "${container_name}" > "${out_file}" 2>&1 || true
fi

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
	echo "Generated file is empty. Removing and skipping." >&2
	rm -f "${out_file}"
	skip "generated file was empty"
fi

line_count=$(wc -l < "${out_file}")
cvar_line_count=$(grep -Eci '^[A-Za-z0-9_.]+[[:space:]]+:' "${out_file}" || true)
has_summary=0
grep -qi 'convars/concommands' "${out_file}" && has_summary=1 || true

echo "Validation stats: lines=${line_count} cvar_lines=${cvar_line_count} has_summary=${has_summary}" >&2

if ((line_count < min_lines)); then
	echo "Too few lines (${line_count} < ${min_lines}). Removing and skipping." >&2
	rm -f "${out_file}"
	skip "not enough output lines"
fi

if ((has_summary == 0)) && ((cvar_line_count < min_cvar_lines)); then
	echo "Incomplete dump (no summary & cvar_lines=${cvar_line_count} < ${min_cvar_lines}). Removing and skipping." >&2
	rm -f "${out_file}"
	skip "incomplete cvar dump"
fi

echo "Display cvarlist"
cat "${out_file}"
