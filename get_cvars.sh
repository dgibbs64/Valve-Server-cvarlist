#!/bin/bash
shortname="${1}"
mkdir linuxgsm
cd linuxgsm || exit
wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh ${shortname}
./${shortname}server auto-install
./${shortname}server start
sleep 10
./${shortname}server send cvarlist
cp log/console/${shortname}server-console.log ../"${shortname}-cvarlist.txt"
./${shortname}server stop

# remove all lines before "cvar list"
echo "Removing all lines before \"cvar list\""
sed -ni -Ee '/cvar list/,$ p' ../"${shortname}-cvarlist.txt"

echo "Tidy"
cd ../ || exit
rm -rf steamcmd
rm -rf linuxgsm