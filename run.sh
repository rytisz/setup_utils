#!/bin/bash
#set -e
#set -o pipefail


#AP='192.168.199.254'
#STA='192.168.199.81'
#SPC='172.17.0.3'
LOCK='/var/lock/LCK..testlab2'
TESTS='tp000,tp002,tp200,tp201,tp202,tp300,tp215'
LOGS='/tmp/'
delay=120

if [ -f $LOCK ]; then
    echo "File $LOCK exists. Please stop manager or remove lock file !!!!!"
    exit 1
fi

source /home/tester/setup_utils/setup_utils.sh
cd "$WORK_DIR"   #workaround for config
echo WORKAROUND: changed dir to: $PWD
while :; do
    waitd TPC AP || { echo 'Can not reach '$AP' exiting tests!!!!';  break; }
    waitd SPC STA || { echo 'Can not reach '$STA' exiting tests!!!!'; break; }
    sleep $delay

    AP -v update
    STA -v update
    sleep $delay

    waitd TPC AP || { echo 'Can not reach '$AP' exiting tests!!!!';  break; }
    waitd SPC STA || { echo 'Can not reach '$STA' exiting tests!!!!';  break; }
    sleep $delay

    AP_FW=`AP fw` && echo "AP: $AP_FW"
    STA_FW=`STA fw` && echo "STA: $STA_FW"

    for SECURITY in "" -WPA2 -ENT2; do
        AP -v set bridge${SECURITY}
        STA -v set bridge5G${SECURITY}
        sleep $delay

        waitd SPC STA || { echo 'Can not reach '$STA' exiting tests!!!!'; break; }
        sleep $delay

        mr5 "$TESTS" "${SECURITY:1:4}, AP: $AP_FW, STA: $STA_FW" | tee "$LOGS`mdate`_5G${SECURITY}_${AP_FW}_$STA_FW"
        sleep $delay

        waitd SPC STA || { echo 'Can not reach '$STA' exiting tests!!!!'; break; }
        sleep $delay

        STA -v set bridge2G${SECURITY}
        sleep $delay

        waitd SPC STA || { echo 'Can not reach '$STA' exiting tests!!!!'; break; }
        sleep $delay

        mr2 "$TESTS" "${SECURITY:1:4}, AP: $AP_FW, STA: $STA_FW" | tee "$LOGS`mdate`_2G${SECURITY}_${AP_FW}_$STA_FW"
        sleep $delay
    done
done
