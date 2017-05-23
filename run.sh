#!/bin/bash
#set -e
#set -o pipefail


AP='192.168.199.254'
STA='192.168.199.81'
SPC='172.17.0.3'
LOCK='/var/lock/LCK..testlab2'
TESTS='tp000 tp002 tp200 tp201 tp202 tp300 tp215'
LOGS='/tmp/'

if [ -f $LOCK ]; then
    echo "File $LOCK exists. Please stop manager or remove lock file !!!!!"
    exit 1
fi

source /home/tester/setup_utils/setup_utils.sh
while :; do 
    download_fw

    TPC -v `waitd $AP`
    SPC -v `waitd $STA`
    sleep 10

    AP -v update
    STA -v update
    sleep 30
    
    TPC -v `waitd $AP`
    SPC -v `waitd $STA`
    sleep 30

    AP_FW=`AP fw` && echo "AP: $AP_FW"
    STA_FW=`STA fw` && echo "STA: $STA_FW"
    
    STA -v set bridge5G
    sleep 40
    
    SPC -v `waitd $STA`
    sleep 10

    mr5 "$TESTS" "AP: $AP_FW, STA: $STA_FW"
    sleep 30

    L=`ls -t $LOGS*.txt | head -n 1`
    mv $L "${L%.txt}_5G_$AP_FW""_$STA_FW"

    STA -v set bridge2G
    sleep 40

    SPC -v `waitd $STA`
    sleep 10
 
    mr2 "$TESTS" "AP: $AP_FW, STA: $STA_FW" 
    sleep 30
    L=`ls -t $LOGS*.txt | head -n 1`
    mv $L "${L%.txt}_2G_$AP_FW""_$STA_FW" 
done 
