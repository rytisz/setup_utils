#!/bin/bash


#ARCHIVE_URI='https://anglerfish.ignitenet.com:58180/archive/qca/SparkWave2/'
#FW_BRANCH='v2.0.0'
#SETUP='qca'
#
#AP='192.168.199.254'
#STA='192.168.199.81'
#TPC='192.168.199.1'
#SPC='192.168.199.161'
#TPC_WAN='172.17.0.2'
#SPC_WAN='172.17.0.3'
#
#TPC_ETH='eth1'
#SPC_ETH='eth2'
#
#SERIAL='/dev/ttyMSM0'
#
#CFG2G='/home/tester/autotestlab/'$SETUP'2.cfg'
#CFG5G='/home/tester/autotestlab/'$SETUP'5.cfg'
#LOGS='/tmp/'

source /home/tester/setup_utils/setup.cfg

RED='\033[0;31m'
NC='\033[0m'

device_run(){
    IP=$1
    PORT=$2
    shift 2
    sshpass -p admin123 ssh -p $PORT root@$IP "$*"
}
device_config(){
    tp=`echo $4 | awk -F '-' '{print $1}' | egrep -o '.{1,2}$' `
    if [ $tp = 2G ]; then
        echo "2G" > /tmp/G
    elif [ $tp = 5G ]; then
        echo "5G" > /tmp/G
    fi
    sshpass -p admin123 scp -P $2 "${3}${4}.tar.gz" root@$1:/tmp/conf.tar.gz &&\
    sshpass -p admin123 ssh -p $2 root@$1 'sysupgrade -r /tmp/conf.tar.gz && reboot'
}
device_backup(){
    sshpass -p admin123 ssh -p $2 root@$1 "sysupgrade -b /tmp/config.tar.gz" &&\
    sshpass -p admin123 scp -P $2 root@$1:"/tmp/config.tar.gz" "${3}${4}.tar.gz"
}
download_fw(){
    /home/tester/autotestlab/fw_upgrade/fw_download.py $FW_BRANCH $ARCHIVE_URI;
}
device_upgrade(){
    sshpass -p admin123 scp -P $2 $3 root@$1:/tmp/fwupdate.bin &&\
    sshpass -p admin123 ssh -p $2 root@$1 'sysupgrade /tmp/fwupdate.bin > '$SERIAL' 2>&1 &'
}
set_ip(){
export declare ${1}=$2
}
DEVICE(){
    DEV_NAME=$1
    IP=$2
    PORT=$3
    BACKUP_DIR=$4
    shift 4
    if [ -z $1 ]
        then device_run $IP $PORT
    elif [ $1 = -v ]; then
        shift; echo "$DEV_NAME: $*"
        DEVICE $DEV_NAME $IP $PORT $BACKUP_DIR $*
    elif [ $1 = update ]; then
        if [ -z $2 ]; then
            FILENAME=$(ls -t $FW_DIR | head -n 1)
        else
            FILENAME=$(ls -t $FW_DIR | grep $2 | head -n 1)
        fi
        echo "Updating $DEV_NAME from $FILENAME"
        device_upgrade $IP $PORT $FILENAME
    elif [ $1 = signal ]; then
        device_run $IP $PORT 'stats -w && sleep 1 && grep -A2 signal /var/run/stats/wireless.json | tail -n2'
    elif [ $1 = set ]; then
        device_config $IP $PORT $BACKUP_DIR $2
    elif [ $1 = tp ]; then
        ls $BACKUP_DIR | sed 's/.tar.gz//g'
    elif [ $1 = backup ]; then
        device_backup $IP $PORT $BACKUP_DIR $2
    elif [ $1 = fw ]; then
        device_run $IP $PORT "cat /etc/version"
    elif [ $1 = IP ]; then
        if [ -z $2 ]; then
            echo ${!DEV_NAME}
            else set_ip $DEV_NAME $2
        fi
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
    elif [ $1 = -v ]; then
        shift; echo "$NAME: $*"
        PC $NAME $IP $PORT $*
    elif [ $1 = IP ]; then
        if [ -z $2 ]; then
            echo ${!NAME}
        else set_ip $NAME $2
        fi
    elif [ $1 = estats ]; then
        INTERFACE="${NAME}_ETH"
        COMMAND='ethstats -n 1 -i '${!INTERFACE}
        PC $NAME $IP $PORT $COMMAND
    else
        sshpass -p tester ssh root@$IP $*
    fi
}
STA() {
    DEVICE "STA" $SPC_WAN 2222 /home/tester/backups/sta/ $*
}
AP() {
    DEVICE "AP" $AP 22 /home/tester/backups/ap/ $*
}
SPC() {
    PC "SPC" $SPC_WAN 22 $*
}
TPC() {
    PC "TPC" $TPC_WAN 22 $*
}
IP() {
    SUBNET='192.168.199.'
    VLAN_SUB='192.168.9.'
    DVLAN_SUB='192.168.99.'
    DEFAULT_SUB='192.168.1.'
    VLAN='9'
    DVLAN='99'
    AP_prefix='254'
    STA_prefix='81'
    TPC_prefix='1'
    SPC_prefix='161'

    flush(){
        echo "ip addr flush dev $2 > /dev/null 2>&1 && echo $1: interface $2 flushed"
    }
    remove(){
        echo "vconfig rem $2 > /dev/null 2>&1 && echo $1: interface $2 removed"
    }
    if [ -z $1 ]; then
        echo "IP flush - flush $TPC_ETH $SPC_ETH interfaces"
        echo "IP [configuration]  - prepere setup for one of posible configurations:"
        echo "bridge, vlan, double_vlan, data_vlan"
    elif [ $1 = flush ]; then
        TPC `flush "TPC" "${TPC_ETH}.${VLAN}.${DVLAN}"`
        TPC `flush "TPC" "${TPC_ETH}.${VLAN}"`
        TPC `flush "TPC" "${TPC_ETH}"`
        SPC `flush "SPC" "${SPC_ETH}.${VLAN}.${DVLAN}"`
        SPC `flush "SPC" "${SPC_ETH}.${VLAN}"`
        SPC `flush "SPC" "${SPC_ETH}"`
        TPC `remove "TPC" "${TPC_ETH}.${VLAN}.${DVLAN}"`
        TPC `remove "TPC" "${TPC_ETH}.${VLAN}"`
        SPC `remove "SPC" "${SPC_ETH}.${VLAN}.${DVLAN}"`
        SPC `remove "SPC" "${SPC_ETH}.${VLAN}"`

    elif [ $1 = bridge ]; then
        IP flush
        AP IP $SUBNET$AP_prefix
        STA IP $SUBNET$STA_prefix
        TPC -v ip a a ${SUBNET}${TPC_prefix}/24 dev $TPC_ETH
        TPC -v ip link set ${TPC_ETH} up
        SPC -v ip a a ${SUBNET}${SPC_prefix}/24 dev $SPC_ETH
        SPC -v ip link set ${SPC_ETH} up

    elif [ $1 = vlan ]; then
        IP bridge
        TPC -v vconfig add ${TPC_ETH} $VLAN
        TPC -v ip a a ${VLAN_SUB}${TPC_prefix}/24 dev ${TPC_ETH}.$VLAN
        TPC -v ip link set ${TPC_ETH}.$VLAN up
        SPC -v vconfig add ${SPC_ETH} $VLAN
        SPC -v ip a a ${VLAN_SUB}${SPC_prefix}/24 dev ${SPC_ETH}.$VLAN
        SPC -v ip link set ${SPC_ETH}.$VLAN up

    elif [ $1 = double_vlan ]; then
        IP vlan
        TPC -v vconfig add ${TPC_ETH}.$VLAN $DVLAN
        TPC -v ip a a ${DVLAN_SUB}${TPC_prefix}/24 dev ${TPC_ETH}.$VLAN.$DVLAN
        TPC -v ip link set ${TPC_ETH}.$VLAN.$DVLAN up
        SPC -v vconfig add ${SPC_ETH}.$VLAN $DVLAN
        SPC -v ip a a ${DVLAN_SUB}${SPC_prefix}/24 dev ${SPC_ETH}.$VLAN.$DVLAN
        SPC -v ip link set ${SPC_ETH}.$VLAN.$DVLAN up
    elif [ $1 = data_vlan ]; then
        IP bridge
        TPC -v vconfig add ${TPC_ETH} $VLAN
        TPC -v ip a a ${VLAN_SUB}${TPC_prefix}/24 dev ${TPC_ETH}.$VLAN
        TPC -v ip link set ${TPC_ETH}.$VLAN up
        SPC -v ip a a ${VLAN_SUB}${SPC_prefix}/24 dev ${SPC_ETH}
        SPC -v ip link set ${SPC_ETH} up
    elif [ $1 = default ]; then
        IP flush
        AP IP "${DEFAULT_SUB}20"
        STA IP "${DEFAULT_SUB}20"
        TPC -v ip a a ${DEFAULT_SUB}${TPC_prefix}/24 dev $TPC_ETH
        TPC -v ip link set ${TPC_ETH} up
        SPC -v ip a a ${DEFAULT_SUB}${SPC_prefix}/24 dev $SPC_ETH
        SPC -v ip link set ${SPC_ETH} up
    else
        echo Topology "'"$1"'" not found
    fi
}
waitd(){
    RETRIES=300
    #echo "n=0; until ping -c1 $1 &>/dev/null; do :;  n=\$n+1; done && echo Pinged to $1 successfuly"
    echo "Trying to ping from $1 to $2 (${!2})"
    `$1 'n=0; until ping -c1 -w1 '${!2}' &>/dev/null; do :; n=$((n+1)); if [ $n = '$RETRIES' ] ; then exit 1; fi ; done'` \
     && echo Pinged $2 successfuly || ( echo Ping to $2 failed; return 1)
}
duration(){
    if [ -z $1 ]; then
        grep ^tp_duration $CFG2G $CFG5G
    else
        sed -i 's/^tp_duration.*/tp_duration                    = '$1'/g' $CFG2G $CFG5G
        grep ^tp_duration $CFG2G $CFG5G
    fi
}
get_duration(){
    grep ^tp_duration $CFG2G $CFG5G
}
mr5(){
    ${WORK_DIR}manager.py -c $CFG5G -e $1 -nu -to metronet --mail -txt "[${SETUP}5] $2"
}
mr2(){
    ${WORK_DIR}manager.py -c $CFG2G -e $1 -nu -to metronet --mail -txt "[${SETUP}2] $2"
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
Stats(){
TESTS=$1 #"tp200 tp215"
SECURITIES=$2 #"NONE -WPA2 -ENT2"

if [ -z "$1" ]; then
    echo 'Usage exampe: Stats "tp002 tp200 tp215" "NONE -ENT2 -WPA2"'
    return 0
fi

printf "h2. Performance results\n\n"

for security in $SECURITIES; do

    for band in 2G 5G; do
        for tc in $TESTS; do

            if [ $security = "-ENT2" ]; then
                sec="WPA2-EAP"
            elif [ $security = "-WPA2" ]; then
                sec="WPA2-PSK"
            else
                sec=""
            fi

            if [ $tc = "tp200" ]; then
                name="$sec PPS"
            elif [ $tc = "tp002" ]; then
                name="$sec Throughput"
            elif [ $tc = "tp215" ]; then
                name="$sec VLAN passtrough"
            elif [ $tc = "tp2092" ]; then
                name="$sec PPS over DATA VLAN"
            else
                name="UNKNOWN"
            fi

            if [ $security == "NONE" ]; then
                last=`ls -t /tmp/*_${band}_* | head -n 30` #| sed 's/:'$tc' .*//')
            else
                last=`ls -t /tmp/*_${band}-${security}_* | head -n 30` #| sed 's/:'$tc' .*//')
            fi
            #echo "$last"
            last=`grep -H ^$tc $last | head -n 1 | sed 's/:'$tc'.*//'`
            #echo "$last"
            formed="`grep '^'$tc' |' ${last}  | awk 'NR%2{printf "%s | ",$0;next;}1'| awk -F '|' '{printf "%s%s%s\n", $2, $4,$8}'  | sed 's/ AP > STA \| bytes\| Mbps  \| KPPS/|/g' | sed 's/  => \|(Expected.*|)//g'`"
            #echo "$formed"
            printf "\nh4. $name ${band}\n\n"
            if [ $tc = "tp215" ]; then
                formed=`echo "$formed" | sed 's/Through //g' | sed 's/None/without/g'`
                echo "|*Toplogogy*            |*Pkt. Size*|*AP->STA*                |*STA->AP*                |"
                echo "${formed}" | awk -F '|'  '{printf "|>.%21s|>.%9s|>.%5s kPPS (%5s Mbps)|>.%5s kPPS (%5s Mbps)|\n", $1, $2 ,$4 ,$3 ,$6, $5}'
            elif [ $tc = "tp002" ]; then
                formed="`grep '^'$tc' | ' ${last} | sed 's/'$tc' |\| ..P. Direction: \| => //g' |  sed 's/Mbps.*/Mbps|/g'`"
                directions=`echo "$formed" | awk -F '|' '{print $1}' |awk '!x[$0]++' `
                echo -n "|*Protocol*|"
                for d in $directions ; do printf '%-14s|' '*'$d'*'; done
                echo
                for proto in "TCP" "UDP"; do
                    formed="`grep '^'$tc' | '$proto ${last} | sed 's/'$tc' |\| ..P. Direction: \| => //g' |  sed 's/Mbps.*/Mbps|/g'`"
                    line=`for d in $directions; do echo "$formed" | grep $d | awk -F '|' '{printf ">.%12s|", $3}' ; done`
                    echo "|$proto       |$line"
                done
            else
                echo "|*Pkt. Size*|*AP->STA*                |*STA->AP*                |"
                echo "${formed}" | awk -F '|'  '{printf "|>.%9s|>.%5s kPPS (%5s Mbps)|>.%5s kPPS (%5s Mbps)|\n", $2 ,$4 ,$3 ,$6, $5}'
            fi
            echo -e "\nMesured:  `echo ${last} | awk -F '_' '{printf "%s %s, AP FW: %s, STA FW: %s\n",$1,$2,$4,$5}'`"| sed 's\'$LOGS'\\'
        done
    done
done
}
setup_info(){
#null to empty
AP_V=`AP 'acc hw all | grep product_name | awk -F "=" '"'"' {printf "\"%s\", ", $2 }'"'"'; cat /etc/version'`
STA_V=`STA 'acc hw all | grep product_name | awk -F "=" '"'"' {printf "\"%s\", ", $2 }'"'"'; cat /etc/version'`
TPC1_V=`TPC 'uname -a'`
SPC1_V=`SPC 'uname -a'`
IFS=$'\n'
TPC_R=($(TPC ip r | grep " $TPC_ETH" | awk '{printf "%-10s%-17s\n",$3,$9}' | sort))
SPC_R=($(SPC ip r | grep " $SPC_ETH" | awk '{printf "%-10s%-17s\n",$3,$9}' | sort))
AP_ip_r=`AP "ip r"`
STA_ip_r=`STA "ip r"`
AP_R=("$(echo "$AP_ip_r" | grep ^default | awk '{printf "%-10s%-17s\n","default:", $3}')"  $(echo -e "$AP_ip_r" | grep -v ^default | awk '{printf "%-10s%-17s\n",$3":",$5}' | sort))
STA_R=("$(echo "$STA_ip_r" | grep ^default | awk '{printf "%-10s%-17s\n","default:", $3}')"  $(echo -e "$STA_ip_r" | grep -v ^default | awk '{printf "%-10s%-17s\n",$3":",$5}' | sort))
n=`echo -e "${#TPC_R[@]}\n${#SPC_R[@]}\n${#AP_R[@]}\n${#STA_R[@]} " | sort -nr | head -n1`
APE=$TPC_ETH
STE=$SPC_ETH
G=`cat /tmp/G`
tput bold
unset IFS
cat << EOF

+----------------------+   +----------------------+ V  ~  ~  ~  ~ V +----------------------+   +----------------------+
|        TPC1          |   |          AP          | |             | |          STA         |   |         SPC1         |
|                      |   |                      | |             | |                      |   |                      |
|                 $APE +---+ eth0        $G radio +-+             +-+ $G radio        eth0 +---+ $STE                 |
|                      |   |             (bridged)|                 |             (bridged)|   |                      |
|                      |   |                      |                 |                      |   |                      |
+----------------------+   +----------------------+                 +----------------------+   +----------------------+
`
for i in $(seq 0 1 $n); do
    printf "%27s%27s%41s%27s\n" "${TPC_R[$i]}" "${AP_R[$i]}" "${STA_R[$i]}" "${SPC_R[$i]}"
done
`

AP:   $AP_V
STA:  $STA_V
TPC1: $TPC1_V
SPC1: $SPC1_V
EOF
tput sgr0
}
config_edit(){
    [ -z $1 ] && ( vim /home/tester/setup_utils/setup.cfg ) || ( cfg="CFG${1}G"; vim ${!cfg} )
}
