#!/bin/bash
shortname="css"
mkdir linuxgsm
cd linuxgsm || exit
wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh ${shortname}
./cssserver auto-install
./cssserver start
sleep 10
./cssserver send cvarlist
cp log/console/cssserver-console.log ../"${shortname}-cvarlist.txt"
./cssserver stop

# remove all lines before "cvar list"
sed -i '1,/cvar list/d' ../"${shortname}-cvarlist.txt"

# remove all lines after "convars/concommands"
sed -i '/convars\/concommands/,$!d' ../"${shortname}-cvarlist.txt"
cd ../ || exit
rm -rf steamcmd
rm -rf linuxgsm
