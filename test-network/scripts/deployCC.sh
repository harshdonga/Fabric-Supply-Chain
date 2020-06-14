
CHANNEL_NAME="$1"
CC_SRC_LANGUAGE="$2"
VERSION="$3"
DELAY="$4"
MAX_RETRY="$5"
VERBOSE="$6"
: ${CHANNEL_NAME:="mychannel"}
: ${CC_SRC_LANGUAGE:="golang"}
: ${VERSION:="2"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}
CC_SRC_LANGUAGE=`echo "$CC_SRC_LANGUAGE" | tr [:upper:] [:lower:]`

FABRIC_CFG_PATH=$PWD/../config/

if [ "$CC_SRC_LANGUAGE" = "go" -o "$CC_SRC_LANGUAGE" = "golang" ] ; then
	CC_RUNTIME_LANGUAGE=golang
	CC_SRC_PATH="../chaincode/fabcar/go/"

	echo Vendoring Go dependencies ...
	pushd ../chaincode/fabcar/go
	GO111MODULE=on go mod vendor
	popd
	echo Finished vendoring Go dependencies

elif [ "$CC_SRC_LANGUAGE" = "javascript" ]; then
	CC_RUNTIME_LANGUAGE=node # chaincode runtime language is node.js
	CC_SRC_PATH="../chaincode/fabcar/javascript/"

else
	echo The chaincode language ${CC_SRC_LANGUAGE} is not supported by this script
	echo Supported chaincode languages are: go, java, javascript, and typescript
	exit 1
fi

# import utils
. scripts/envVar.sh


packageChaincode() {
  ORG=$1
  PEER=$2
  setGlobals $1 $2
  set -x
  peer lifecycle chaincode package fabcar.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label fabcar_${VERSION} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode packaging on peer${PEER}.org${ORG} has failed"
  echo "===================== Chaincode is packaged on peer${PEER}.org${ORG} ===================== "
  echo
}

# installChaincode PEER ORG
installChaincode() {
  ORG=$1
  PEER=$2
  setGlobals $1 $2
  set -x
  peer lifecycle chaincode install fabcar.tar.gz >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on peer$2.org${ORG} has failed"
  echo "===================== Chaincode is installed on peer$2.org${ORG} ===================== "
  echo
}

# queryInstalled PEER ORG
queryInstalled() {
  ORG=$1
  PEER=$2
  setGlobals $1 $2
  set -x
  peer lifecycle chaincode queryinstalled >&log.txt
  res=$?
  set +x
  cat log.txt
	PACKAGE_ID=$(sed -n "/fabcar_${VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
  verifyResult $res "Query installed on peer${PEER}.org${ORG} has failed"
  echo PackageID is ${PACKAGE_ID}
  echo "===================== Query installed successful on peer${PEER}.org${ORG} on channel ===================== "
  echo
}

# approveForMyOrg VERSION PEER ORG
approveForMyOrg() {
  PEER=$2
  ORG=$1
  setGlobals $ORG $PEER

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID $CHANNEL_NAME --name fabcar --version ${VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${VERSION} >&log.txt
    # peer lifecycle chaincode approveformyorg --channelID $CHANNEL_NAME --name fabcar --version ${VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${VERSION} --waitForEvent >&log.txt
    set +x
  else
    set -x
  peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name fabcar --version ${VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${VERSION} >&log.txt
    # peer lifecycle chaincode approveformyorg --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name fabcar --version ${VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${VERSION} --waitForEvent >&log.txt
    set +x
  fi
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode definition approved on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  echo
}
# approveForMyOrg() {
#   ORG=$1
#   setGlobal $ORG
#   set -x
#   peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name fabcar --version ${VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${VERSION} >&log.txt
#   set +x
#   cat log.txt
#   verifyResult $res "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
#   echo "===================== Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME' ===================== "
#   echo
# }

# checkCommitReadiness VERSION PEER ORG
checkCommitReadiness() {
  # VERSION=$1
  PEER=$2
  ORG=$1
  shift 2
  setGlobals $ORG $PEER
  echo "===================== Checking the commit readiness of the chaincode definition on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME'... ===================== "
  local rc=1
  local starttime=$(date +%s)
  local rc=1
	local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  # while
    # test "$(($(date +%s) - starttime))" -lt "$TIMEOUT" -a $rc -ne 0
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    echo "Attempting to check the commit readiness of the chaincode definition on peer${PEER}.org${ORG} ...$(($(date +%s) - starttime)) secs"
    set -x
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name fabcar $PEER_CONN_PARMS --version ${VERSION} --sequence ${VERSION} --output json --init-required >&log.txt
    res=$?
    set +x
    test $res -eq 0 || continue
    let rc=0
    for var in "$@"
    do
        grep "$var" log.txt &>/dev/null || let rc=1
    done
  done
  echo
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Checking the commit readiness of the chaincode definition successful on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  else
    echo "!!!!!!!!!!!!!!! Check commit readiness result on peer${PEER}.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
    echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
    echo
    exit 1
  fi
}
# checkCommitReadiness() {
#   ORG=$1
#   shift 1
#   setGlobal $1
#   echo "===================== Checking the commit readiness of the chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'... ===================== "
# 	local rc=1
# 	local COUNTER=1
# 	# continue to poll
#   # we either get a successful response, or reach MAX RETRY
# 	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
#     sleep $DELAY
#     echo "Attempting to check the commit readiness of the chaincode definition on peer0.org${ORG} secs"
#     set -x
#     peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name fabcar --version ${VERSION} --sequence ${VERSION} --output json --init-required >&log.txt
#     res=$?
#     set +x
#     let rc=0
#     # for var in "$@"
#     # do
#       grep "$@" log.txt &>/dev/null || let rc=1
#     # done
# 		COUNTER=$(expr $COUNTER + 1)
# 	done
#   cat log.txt
#   if test $rc -eq 0; then
#     echo "===================== Checking the commit readiness of the chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME' ===================== "
#   else
#     echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Check commit readiness result on peer0.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
#     echo
#     exit 1
#   fi
# }

# commitChaincodeDefinition VERSION PEER ORG (PEER ORG)...
commitChaincodeDefinition() {
  # VERSION=$1
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID $CHANNEL_NAME --name fabcar $PEER_CONN_PARMS --version ${VERSION} --sequence ${VERSION} --init-required >&log.txt
    res=$?
    set +x
  else
    set -x
    peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name fabcar $PEER_CONN_PARMS --version ${VERSION} --sequence ${VERSION} --init-required >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode definition committed on channel '$CHANNEL_NAME' ===================== "
  echo
}
# commitChaincodeDefinition() {
#   # ORG=$1
#   # PEER=$2
#   parsePeerConnectionParameters $@
#   res=$?
#   verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

#   # while 'peer chaincode' command can get the orderer endpoint from the
#   # peer (if join was successful), let's supply it directly as we know
#   # it using the "-o" option
#   set -x
#   peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name fabcar $PEER_CONN_PARMS --version ${VERSION} --sequence ${VERSION} --init-required >&log.txt
#   res=$?
#   set +x
#   cat log.txt
#   verifyResult $res "Chaincode definition commit failed on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' failed"
#   echo "===================== Chaincode definition committed on channel '$CHANNEL_NAME' ===================== "
#   echo
# }

# queryCommitted ORG

queryCommitted() {
  # VERSION=$1
  PEER=$2
  ORG=$1
  setGlobals $ORG $PEER
  EXPECTED_RESULT="Version: ${VERSION}, Sequence: ${VERSION}, Endorsement Plugin: escc, Validation Plugin: vscc"
  echo "===================== Querying chaincode definition on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME'... ===================== "
  local rc=1
  local starttime=$(date +%s)
	local rc=1
	local COUNTER=1
	# continue to poll
  # we either get a successful response, or reach MAX RETRY
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    echo "Attempting to Query committed status on peer${PEER}.org${ORG} ...$(($(date +%s) - starttime)) secs"
    set -x
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name fabcar >&log.txt
    res=$?
    set +x
    test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: [0-9], Sequence: [0-9], Endorsement Plugin: escc, Validation Plugin: vscc')
    test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Query chaincode definition successful on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  else
    echo "!!!!!!!!!!!!!!! Query chaincode definition result on peer${PEER}.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
    echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
    echo
    exit 1
  fi
}

# queryCommitted() {
#   ORG=$1
#   # PEER=$2
#   setGlobal $ORG
#   EXPECTED_RESULT=": ${VERSION}, Sequence: ${VERSION}, Endorsement Plugin: escc, Validation Plugin: vscc"
#   echo "===================== Querying chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'... ===================== "
# 	local rc=1
# 	local COUNTER=1
# 	# continue to poll
#   # we either get a successful response, or reach MAX RETRY
# 	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
#     sleep $DELAY
#     echo "Attempting to Query committed status on peer0.org${ORG}, Retry after $DELAY seconds."
#     set -x
#     peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name fabcar >&log.txt
#     res=$?
#     set +x
# 		test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: [0-9], Sequence: [0-9], Endorsement Plugin: escc, Validation Plugin: vscc')
#     test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
# 		COUNTER=$(expr $COUNTER + 1)
# 	done
#   echo
#   cat log.txt
#   if test $rc -eq 0; then
#     echo "===================== Query chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME' ===================== "
# 		echo
#   else
#     echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Query chaincode definition result on peer0.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
#     echo
#     exit 1
#   fi
# }

chaincodeInvokeInit() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  set -x
  peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n fabcar $PEER_CONN_PARMS --isInit -c '{"function":"initLedger","Args":[]}' >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  echo "===================== Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME' ===================== "
  echo
}

chaincodeQuery() {
  ORG=$1
  PEER=$2
  setGlobals $ORG $PEER
  echo "===================== Querying on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME'... ===================== "
	local rc=1
	local COUNTER=1
	# continue to poll
  # we either get a successful response, or reach MAX RETRY
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    echo "Attempting to Query peer${PEER}.org${ORG} ...$(($(date +%s) - starttime)) secs"
    set -x
    peer chaincode query -C $CHANNEL_NAME -n fabcar -c '{"Args":["queryAllCars"]}' >&log.txt
    res=$?
    set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
  echo
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Query successful on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
		echo
  else
    echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Query result on peer${PEER}.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

# at first we package the chaincode
packageChaincode 1 0
packageChaincode 1 1
packageChaincode 2 0
packageChaincode 3 0
packageChaincode 3 1
packageChaincode 3 2

## Install chaincode on peer0.org1 and peer0.org2
echo "Installing chaincode on peer0.org1..."
installChaincode 1 0
installChaincode 1 1

echo "Install chaincode on peer0.org2..."
installChaincode 2 0

echo "Install chaincode on peer0.org3..."
installChaincode 3 0
installChaincode 3 1
installChaincode 3 2


## query whether the chaincode is installed
queryInstalled 1 0
queryInstalled 1 1

## approve the definition for org1
approveForMyOrg 1 0
# approveForMyOrg 1 1

## check whether the chaincode definition is ready to be committed
## expect org1 to have approved and org2 not to
checkCommitReadiness 1 0 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"
# checkCommitReadiness 1 1 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"
checkCommitReadiness 2 0 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"
checkCommitReadiness 3 0 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"
# checkCommitReadiness 3 1 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"
# checkCommitReadiness 3 2 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"

## now approve also for org2
approveForMyOrg 2 0

## check whether the chaincode definition is ready to be committed
## expect them both to have approved
checkCommitReadiness 1 0 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"
# checkCommitReadiness 1 1 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"
checkCommitReadiness 2 0 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"
checkCommitReadiness 3 0 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"
# checkCommitReadiness 3 1 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"
# checkCommitReadiness 3 2 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"


## now approve also for org3
approveForMyOrg 3 0
# approveForMyOrg 3 1
# approveForMyOrg 3 2


## check whether the chaincode definition is ready to be committed
## expect them both to have approved
checkCommitReadiness 1 0 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"
# checkCommitReadiness 1 1 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"
checkCommitReadiness 2 0 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"
checkCommitReadiness 3 0 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"
# checkCommitReadiness 3 1 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"
# checkCommitReadiness 3 2 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"



# now that we know for sure all orgs have approved, commit the definition
commitChaincodeDefinition 1 0 1 1 2 0 3 0 3 1 3 2
# commitChaincodeDefinition 1 1
# commitChaincodeDefinition 2 0
# commitChaincodeDefinition 3 0
# commitChaincodeDefinition 3 1
# commitChaincodeDefinition 3 2

# query on both orgs to see that the definition committed successfully
queryCommitted 1 0
queryCommitted 1 1
queryCommitted 2 0
queryCommitted 3 0
queryCommitted 3 1
queryCommitted 3 2

## Invoke the chaincode
chaincodeInvokeInit 1 0 1 1 2 0 3 0 3 1 3 2
# chaincodeInvokeInit 1 1
# chaincodeInvokeInit 2 0
# chaincodeInvokeInit 3 0
# chaincodeInvokeInit 3 1
# chaincodeInvokeInit 3 2


sleep 10

# Query chaincode on peer0.org1
echo "Querying chaincode on peer0.org1..."
chaincodeQuery 3 2

exit 0
