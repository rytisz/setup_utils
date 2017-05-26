# setup_utils

## How to setup:
* Add your setup config file to /home/tester/setup_utils/ Example:
```
ARCHIVE_URI='https://anglerfish.ignitenet.com:58180/archive/qca/SparkWave2/'
FW_BRANCH='v2.0.0'
SETUP='qca'

AP='192.168.199.254'
STA='192.168.199.81'
TPC='192.168.199.1'
SPC='192.168.199.161'
TPC_WAN='172.17.0.2'
SPC_WAN='172.17.0.3'

AP_ETH='eth1'
STA_ETH='eth2'

SERIAL='/dev/ttyMSM0'

CFG2G='/home/tester/autotestlab/'$SETUP'2.cfg'
CFG5G='/home/tester/autotestlab/'$SETUP'5.cfg'
LOGS='/tmp/'
```
* Add source setup_utils.sh to ~/.bashrc
```
echo >> "source /home/tester/setup_utils/setup_utils.sh" ~/.bashrc
```
