#!/bin/bash
# cs2_cvarlist.sh
# Author: Daniel Gibbs
# Website: http://danielgibbs.co.uk
# Version: 231105
# Description: CS2 does not have a "list all" command to get all command options within CS2.
# Instead you have use find <string>
# This script outputs all the commands available and saves it to a file

rootdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
executabledir="${rootdir}/serverfiles"
executable="./srcds_run"
parameters="-game cstrike +cvarlist +quit"
steamcmd +force_install_dir "${rootdir}/serverfiles" +login anonymous +app_update "232330" +quit

echo ""
echo "Getting CS2 Commands/Convars"
echo "================================="
cd "${executabledir}"
echo "${executable} ${parameters}"
unbuffer ./srcds_run -game cstrike +cvarlist +quit > "${rootdir}/cvarlist.txt"
dos2unix "${rootdir}/cvarlist.txt"

# remove all lines before "cvar list"
sed -i '1,/cvar list/d' "${rootdir}/cvarlist.txt"

# remove all lines after "convars/concommands"
sed -i '/convars\/concommands/,$!d' "${rootdir}/cvarlist.txt"