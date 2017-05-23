#!/bin/bash


ARCHIVE_URI='https://anglerfish.ignitenet.com:58180/archive/qca/SparkWave2/'
FW_BRANCH='v2.0.0'
SETUP='qca'

AP='192.168.199.254'
STA='192.168.199.81'
TPC='172.17.0.2'
SPC='172.17.0.3'

AP_ETH='tpc1'
STA_ETH='eth2'

SERIAL='/dev/ttyMSM0'

CFG2G='/home/tester/autotestlab/'$SETUP'2.cfg'
CFG5G='/home/tester/autotestlab/'$SETUP'5.cfg'
LOGS='/tmp/'

RED='\033[0;31m'
NC='\033[0m'

device_run(){
    IP=$1
    PORT=$2
    shift 2
    sshpass -p admin123 ssh -p $PORT root@$IP "$*"
}
device_config(){
    sshpass -p admin123 scp -P $2 $3 root@$1:/tmp/conf.tar.gz
    sshpass -p admin123 ssh -p $2 root@$1 'sysupgrade -r /tmp/conf.tar.gz && reboot'
}
device_backup(){
    sshpass -p admin123 ssh -p $2 root@$1 "sysupgrade -b /tmp/config.tar.gz"
    sshpass -p admin123 scp -P $2 root@$1:"/tmp/config.tar.gz" $3
}
download_fw(){
    /home/tester/autotestlab/fw_upgrade/fw_download.py $FW_BRANCH $ARCHIVE_URI;
}
device_upgrade(){
    sshpass -p admin123 scp -P $2 $3 root@$1:/tmp/fwupdate.bin
    sshpass -p admin123 ssh -p $2 root@$1 'sysupgrade /tmp/fwupdate.bin > '$SERIAL' 2>&1 &'
}
DEVICE(){
    DEV_NAME=$1
    IP=$2
    PORT=$3
    BACKUP_DIR=$4
    shift 4
    if [ -z $1 ]
        then device_run $IP $PORT
    elif [ $1 = -v ]
        then shift; echo "$DEV_NAME: $*"
        DEVICE $DEV_NAME $IP $PORT $BACKUP_DIR $*
    elif [ $1 = update ]
        then device_upgrade $IP $PORT /tmp/latest.bin
    elif [ $1 = signal ]
        then  device_run $IP $PORT 'stats -w && grep -A2 signal /var/run/stats/wireless.json | tail -n2'
    elif [ $1 = set ]
        then device_config $IP $PORT $BACKUP_DIR$2'.tar.gz'
    elif [ $1 = tp ]
        then ls $BACKUP_DIR | sed 's/.tar.gz//g'
    elif [ $1 = backup ]
        then device_backup $IP $PORT $BACKUP_DIR$2'.tar.gz'
    elif [ $1 = fw ]
        then device_run $IP $PORT "cat /etc/version"
    else device_run $IP $PORT "$*"
    fi
}
PC(){
    NAME=$1
    IP=$2
    PORT=$3
    shift 3
    if [ -z $1 ]
        then sshpass -p tester ssh root@$IP
    elif [ $1 = -v ]
        then shift; echo "$NAME: $*"
        PC $NAME $IP $PORT $*
    else
        sshpass -p tester ssh root@$IP $*
    fi
}
STA() {
    DEVICE "SPC" $SPC 2222 /home/tester/backups/sta/ $*
}
AP() {
    DEVICE "AP" $AP 22 /home/tester/backups/ap/ $*
}
SPC() {
    PC "SPC" $SPC 22 $*
}
TPC() {
    PC "TPC" $TPC 22 $*
}
IP() {
    SUBNET='192.168.199.'
    VLAN_SUB='192.168.9.'
    DVLAN_SUB='192.168.99.'
    DEFAULT_SUB='192.168.1.'
    VLAN='9'
    DVLAN='99'
    AP_prefix='1'
    STA_prefix='161'

    flush(){
        echo "ip addr flush dev $2 > /dev/null 2>&1 && echo $1: interface $2 flushed"
    }
    remove(){
        echo "vconfig rem $2 > /dev/null 2>&1 && echo $1: interface $2 removed"
    }
    if [ -z $1 ]; then
        echo "IP flush - flush $AP_ETH $STA_ETH interfaces"
        echo "IP [configuration]  - prepere setup for one of posible configurations:"
        echo "bridge, vlan, double_vlan, data_vlan"
    elif [ $1 = flush ]; then
        TPC `flush "TPC" "${AP_ETH}.${VLAN}.${DVLAN}"`
        TPC `flush "TPC" "${AP_ETH}.${VLAN}"`
        TPC `flush "TPC" "${AP_ETH}"`
        SPC `flush "SPC" "${STA_ETH}.${VLAN}.${DVLAN}"`
        SPC `flush "SPC" "${STA_ETH}.${VLAN}"`
        SPC `flush "SPC" "${STA_ETH}"`
        TPC `remove "TPC" "${AP_ETH}.${VLAN}.${DVLAN}"`
        TPC `remove "TPC" "${AP_ETH}.${VLAN}"`
        SPC `remove "SPC" "${STA_ETH}.${VLAN}.${DVLAN}"`
        SPC `remove "SPC" "${STA_ETH}.${VLAN}"`

    elif [ $1 = bridge ] ; then
        IP flush
        TPC -v ip a a ${SUBNET}${AP_prefix}/24 dev $AP_ETH
        TPC -v ip link set ${AP_ETH} up
        SPC -v ip a a ${SUBNET}${STA_prefix}/24 dev $STA_ETH
        SPC -v ip link set ${STA_ETH} up

    elif [ $1 = vlan ] ; then
        IP bridge
        TPC -v vconfig add ${AP_ETH} $VLAN
        TPC -v ip a a ${VLAN_SUB}${AP_prefix}/24 dev ${AP_ETH}.$VLAN
        TPC -v ip link set ${AP_ETH}.$VLAN up
        SPC -v vconfig add ${STA_ETH} $VLAN
        SPC -v ip a a ${VLAN_SUB}${STA_prefix}/24 dev ${STA_ETH}.$VLAN
        SPC -v ip link set ${STA_ETH}.$VLAN up

    elif [ $1 = double_vlan ] ; then
        IP vlan
        TPC -v vconfig add ${AP_ETH}.$VLAN $DVLAN
        TPC -v ip a a ${DVLAN_SUB}${AP_prefix}/24 dev ${AP_ETH}.$VLAN.$DVLAN
        TPC -v ip link set ${AP_ETH}.$VLAN.$DVLAN up
        SPC -v vconfig add ${STA_ETH}.$VLAN $DVLAN
        SPC -v ip a a ${DVLAN_SUB}${STA_prefix}/24 dev ${STA_ETH}.$VLAN.$DVLAN
        SPC -v ip link set ${STA_ETH}.$VLAN.$DVLAN up
    elif [ $1 = data_vlan ] ; then
        IP bridge
        TPC -v vconfig add ${AP_ETH} $VLAN
        TPC -v ip a a ${VLAN_SUB}${AP_prefix}/24 dev ${AP_ETH}.$VLAN
        TPC -v ip link set ${AP_ETH}.$VLAN up
        SPC -v ip a a ${VLAN_SUB}${STA_prefix}/24 dev ${STA_ETH}
        SPC -v ip link set ${STA_ETH} up
    elif [ $1 = default ] ; then
        IP flush
        TPC -v ip a a ${DEFAULT_SUB}${AP_prefix}/24 dev $AP_ETH
        TPC -v ip link set ${AP_ETH} up
        SPC -v ip a a ${DEFAULT_SUB}${STA_prefix}/24 dev $STA_ETH
        SPC -v ip link set ${STA_ETH} up
    else
        echo Topology "'"$1"'" not found
    fi
}
waitd(){
    echo "echo Waiting till $1 will be reachable;";
    echo "until ping -c1 $1 &>/dev/null; do :; done && echo Pinged to $1 successfuly"
}
duration(){
    sed -i 's/^tp_duration.*/tp_duration                    = '$1'/g' $CFG2G $CFG5G
    grep ^tp_duration /home/tester/autotestlab/qca*.cfg
}
get_duration(){
    grep ^tp_duration $CFG2G $CFG5G
}
mr5(){
    /home/tester/autotestlab/manager.py -c $CFG5G -e $1 -nu -to metronet --mail -txt "[${SETUP}5] $2"
}
mr2(){
    /home/tester/autotestlab/manager.py -c $CFG2G -e $1 -nu -to metronet --mail -txt "[${SETUP}2] $2"
}
utils_edit(){
    vim /home/tester/setup_utils/setup_utils.sh ;
    source /home/tester/setup_utils/setup_utils.sh
}
run_edit(){
    vim /home/tester/setup_utils/run.sh ;
}
run_tests(){
    /home/tester/setup_utils/run.sh
}
PPS_Stats(){
TESTS="tp200 tp215 tp2092"
for tc in tp200 tp215 tp2092; do
    for band in 2G 5G; do
        if [ $tc = "tp200" ]; then
            name="PPS"
        elif [ $tc = "tp215" ]; then
            name="VLAN passtrough"
        elif [ $tc = "tp2092" ]; then
            name="PPS over DATA VLAN"
        fi
            
        declare last_${tc}_${band}=$(grep ^$tc `ls -t /tmp/*_${band}_*` | head -n 1 | sed 's/:'$tc' .*//')
        log="last_${tc}_$band"
        declare formed_${tc}_${band}="`grep '^'$tc' |' ${!log}  | awk 'NR%2{printf "%s | ",$0;next;}1'| awk -F '|' '{printf "%s%s%s\n", $2, $4,$8}'  | sed 's/ AP > STA \| bytes\| Mbps  \| KPPS/|/g' | sed 's/  => \|//g'`"
        formed="formed_${tc}_${band}"
        
        printf "\nh4. $name ${band}\n\n"
        if [ $tc = "tp215" ]; then
            echo "|*Toplogogy*            |*Pkt. Size*|*AP->STA*                |*STA->AP*                |"
            echo "${!formed}" | awk -F '|'  '{printf "|>.%20s|>.%9s|>.%5s kPPS (%5s Mbps)|>.%5s kPPS (%5s Mbps)|\n", $1, $2 ,$4 ,$3 ,$6, $5}'
        else
            echo "|*Pkt. Size*|*AP->STA*                |*STA->AP*                |"
            echo "${!formed}" | awk -F '|'  '{printf "|>.%9s|>.%5s kPPS (%5s Mbps)|>.%5s kPPS (%5s Mbps)|\n", $2 ,$4 ,$3 ,$6, $5}'
        fi
        echo -e "\nMesured:  `echo ${!log} | awk -F '_' '{printf "%s %s, AP FW: %s, STA FW: %s\n",$1,$2,$4,$5}'`"| sed 's\'$LOGS'\\'
    done
done
}
