#!/bin/sh

echo "*************************************************************************"

echo "`date "+[%Y-%m-%d %H:%M:%S]"` Updating ethprice..."
~/MPEToken/SmartContract/scripts/getLastEthPrice.sh

cd ~/MPEToken/SmartContract

export PATH=$PATH:/usr/local/bin

echo "*************************************************************************"

echo "`date "+[%Y-%m-%d %H:%M:%S]"` Updating mainnet..."
/usr/local/bin/truffle exec scripts/UpdateETHPrice.js --network mainnet `tail -1 scripts/ethprice.dat|awk -F ',' '{print $2}'`

echo "`date "+[%Y-%m-%d %H:%M:%S]"` Updating roptsten..."
/usr/local/bin/truffle exec scripts/UpdateETHPrice.js --network ropsten `tail -1 scripts/ethprice.dat|awk -F ',' '{print $2}'`

echo "`date "+[%Y-%m-%d %H:%M:%S]"` Stopped."

cd - 1>/dev/null 2>&1

