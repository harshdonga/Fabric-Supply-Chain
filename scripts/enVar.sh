export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/msc.com/orderers/orderer.msc.com/msp/tlscacerts/tlsca.msc.com-cert.pem
export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.msc.com/peers/peer0.org1.msc.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.msc.com/peers/peer0.org2.msc.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/organizations/peerOrganizations/org3.msc.com/peers/peer0.org3.msc.com/tls/ca.crt

# Set OrdererOrg.Admin globals
setOrdererGlobals() {
  export CORE_PEER_LOCALMSPID="OrdererMSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/ordererOrganizations/msc.com/orderers/orderer.msc.com/msp/tlscacerts/tlsca.msc.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/ordererOrganizations/msc.com/users/Admin@msc.com/msp
}

# Set environment variables for the peer org
setGlobals() {
  PEER=$1
  ORG=$2
  echo "Using organization ${ORG}"
  if [ $ORG -eq 1 ]; then
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.msc.com/users/Admin@org1.msc.com/msp
    if [ $PEER -eq 0 ]; then
      export CORE_PEER_ADDRESS=localhost:7051
    else
      export CORE_PEER_ADDRESS=localhost:7061
    fi

  elif [ $ORG -eq 2 ]; then
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.msc.com/users/Admin@org2.msc.com/msp
    export CORE_PEER_ADDRESS=localhost:8051

  elif [ $ORG -eq 3 ]; then
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.msc.com/users/Admin@org3.msc.com/msp
    if [ $PEER -eq 0 ]; then
      export CORE_PEER_ADDRESS=localhost:9051
    elif [ $PEER -eq 1 ]; then
      export CORE_PEER_ADDRESS=localhost:9061
    else
      export CORE_PEER_ADDRESS=localhost:9071
    fi    
  else
    echo "================== ERROR !!! ORG Unknown =================="
  fi

  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}



# Helper function that sets the peer connection parameters for a chaincode
# operation
parsePeerConnectionParameters() {

  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1 $2
    PEER="peer$1.org$2"
    PEERS="$PEERS $PEER"
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    ## Set path to TLS certificate
    TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER$1_ORG$2_CA")
    PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
    # shift by one to get to the next organization
    shift
    shift
  done
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
}


verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}
