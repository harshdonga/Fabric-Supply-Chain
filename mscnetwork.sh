#!/bin/bash

echo
echo "  _____________________________________________"
echo " //                                           //"
echo " //      _       ______     _       __  __    //"
echo " //     / \     /_   _/    / \      \ \/ /    //"
echo " //    / _ \      | |     / _ \      \  /     //"
echo " //   / ___ \   __| |    / ___ \    / /\ \    //"
echo " //  /_/   \_\  \___|   /_/   \_\  /_/  \_\   //" 
echo " //                                           //"
echo " //___________________________________________//"
echo

export PATH=${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false
BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\. ^1\.2\. ^1\.3\. ^1\.4\."


function printHelp() {
  echo "Usage: "
  echo "  mscnetwork.sh <Mode> [Flags]"
  echo "    <Mode>"
  echo "      - 'up' - bring up fabric orderer and peer nodes. No channel is created"
  echo "      - 'up createChannel' - bring up fabric network with one channel"
  echo "      - 'createChannel' - create and join a channel after the network is created"
  echo "      - 'deployCC' - deploy the fabcar chaincode on the channel"
  echo "      - 'down' - clear the network with docker-compose down"
  echo "      - 'restart' - restart the network"
  echo
  echo "    Flags:"
  echo "    -ca <use CAs> -  create Certificate Authorities to generate the crypto material"
  echo "    -c <channel name> - channel name to use (defaults to \"mychannel\")"
  echo "    -s <dbtype> - the database backend to use: goleveldb (default) or couchdb"
  echo "    -r <max retry> - CLI times out after certain number of attempts (defaults to 5)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -l <language> - the programming language of the chaincode to deploy: go (default), java, javascript, typescript"
  echo "    -v <version>  - chaincode version. Must be a round number, 1, 2, 3, etc"
  echo "    -i <imagetag> - the tag to be used to launch the network (defaults to \"latest\")"
  echo "    -verbose - verbose mode"
  echo "  mscnetwork.sh -h (print this message)"
  echo
  echo " Possible Mode and flags"
  echo "  mscnetwork.sh up -ca -c -r -d -s -i -verbose"
  echo "  mscnetwork.sh up createChannel -ca -c -r -d -s -i -verbose"
  echo "  mscnetwork.sh createChannel -c -r -d -verbose"
  echo "  mscnetwork.sh deployCC -l -v -r -d -verbose"
  echo
  echo " Taking all defaults:"
  echo "	mscnetwork.sh up"
  echo
  echo " Examples:"
  echo "  mscnetwork.sh up createChannel -ca -c mychannel -s couchdb -i 2.0.0"
  echo "  mscnetwork.sh createChannel -c channelName"
  echo "  mscnetwork.sh deployCC -l javascript"
}

#remove already present containers
function clearContainers() {
  CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')
  if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
    echo "---- No containers available for deletion ----"
  else
    docker rm -f $CONTAINER_IDS
  fi
}

#remove unwanted images
function removeUnwantedImages() {
  DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*/) {print $3}')
  if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
    echo "---- No images available for deletion ----"
  else
    docker rmi -f $DOCKER_IMAGE_IDS
  fi
}


#prerequisites
function checkPrereqs() {
  peer version > /dev/null 2>&1

  if [[ $? -ne 0 || ! -d "../config" ]]; then
    echo "ERROR! Peer binary and configuration files not found.."
    exit 1
  fi
  LOCAL_VERSION=$(peer version | sed -ne 's/ Version: //p')
  DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:$IMAGETAG peer version | sed -ne 's/ Version: //p' | head -1)

  echo "LOCAL_VERSION=$LOCAL_VERSION"
  echo "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
    echo "=================== WARNING ==================="
    echo "  Local fabric binaries and docker images are  "
    echo "  out of  sync. This may cause problems.       "
    echo "==============================================="
  fi

  for UNSUPPORTED_VERSION in $BLACKLISTED_VERSIONS; do
    echo "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      echo "ERROR! Local Fabric binary version of $LOCAL_VERSION does not match the versions supported by the test network."
      exit 1
    fi

    echo "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      echo "ERROR! Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match the versions supported by the test network."
      exit 1
    fi
  done
}


#crypto ca or cryptogen
function createOrgs() {

  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi

  # Create crypto material using cryptogen
  if [ "$CRYPTO" == "cryptogen" ]; then
    which cryptogen
    if [ "$?" -ne 0 ]; then
      echo "cryptogen tool not found. exiting"
      exit 1
    fi
    echo
    echo "#################### Cryptogen tool #####################"
    echo

    echo "############ Create Org1 Identities ######################"
    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-org1.yaml --output="organizations"
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate certificates..."
      exit 1
    fi

    echo "############ Create Org2 Identities ######################"
    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-org2.yaml --output="organizations"
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate certificates..."
      exit 1
    fi

    echo "############ Create Org3 Identities ######################"
    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-org3.yaml --output="organizations"
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate certificates..."
      exit 1
    fi


    echo "############ Create Orderer Org Identities ###############"
    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-orderer.yaml --output="organizations"
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate certificates..."
      exit 1
    fi
  fi

#   # Create crypto material using Fabric CAs
#   if [ "$CRYPTO" == "Certificate Authorities" ]; then

#     fabric-ca-client version > /dev/null 2>&1
#     if [ $? -ne 0 ]; then
#       echo "Fabric CA client not found locally, downloading..."
#       cd ..
#       curl -s -L "https://github.com/hyperledger/fabric-ca/releases/download/v1.4.4/hyperledger-fabric-ca-${OS_ARCH}-1.4.4.tar.gz" | tar xz || rc=$?
#     if [ -n "$rc" ]; then
#         echo "==> There was an error downloading the binary file."
#         echo "fabric-ca-client binary is not available to download"
#     else
#         echo "==> Done."
#       cd MSC
#     fi
#     fi

#     echo
#     echo "##########################################################"
#     echo "##### Generate certificates using Fabric CA's ############"
#     echo "##########################################################"

#     IMAGE_TAG=$IMAGETAG docker-compose -f $COMPOSE_FILE_CA up -d 2>&1

#     . organizations/fabric-ca/registerEnroll.sh

#     sleep 10

#     echo "##########################################################"
#     echo "############ Create Org1 Identities ######################"
#     echo "##########################################################"

#     createOrg1

#     echo "##########################################################"
#     echo "############ Create Org2 Identities ######################"
#     echo "##########################################################"

#     createOrg2

#     echo "##########################################################"
#     echo "############ Create Orderer Org Identities ###############"
#     echo "##########################################################"

#     createOrderer

#   fi

  echo
  echo "Generate CCP files for Org1, Org2 & Org3"
  ./organizations/ccp-generate.sh
}


#consortium
function createConsortium() {

  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "#########  Generating Orderer Genesis block ##############"
  set -x
  configtxgen -profile ThreeOrgsOrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
}


function networkUp() {

  checkPrereqs
  if [ ! -d "organizations/peerOrganizations" ]; then
    createOrgs
    createConsortium
  fi

  COMPOSE_FILES="-f ${COMPOSE_FILE_BASE}"

  if [ "${DATABASE}" == "couchdb" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_COUCH}"
  fi

  IMAGE_TAG=$IMAGETAG docker-compose ${COMPOSE_FILES} up -d 2>&1

  docker ps -a
  if [ $? -ne 0 ]; then
    echo "*********** Unable to start network **************"
    exit 1
  fi
}


function createChannel() {
  if [ ! -d "organizations/peerOrganizations" ]; then
    echo "Bringing up network"
    networkUp
  fi

 scripts/createChannel.sh $CHANNEL_NAME $CLI_DELAY $MAX_RETRY $VERBOSE
  if [ $? -ne 0 ]; then
    echo "********** Create channel failed ****************"
    exit 1
  fi

}


function deployCC() {

  scripts/deployCC.sh $CHANNEL_NAME $CC_SRC_LANGUAGE $VERSION $CLI_DELAY $MAX_RETRY $VERBOSE
  if [ $? -ne 0 ]; then
    echo "********** Deploying chaincode failed **********"
    exit 1
  fi

  exit 0
}


function networkDown() {
  docker-compose -f $COMPOSE_FILE_BASE -f $COMPOSE_FILE_COUCH -f $COMPOSE_FILE_CA down --volumes --remove-orphans
  docker-compose -f $COMPOSE_FILE_COUCH_ORG3 -f $COMPOSE_FILE_ORG3 down --volumes --remove-orphans
  if [ "$MODE" != "restart" ]; then
    clearContainers
    removeUnwantedImages
    rm -rf system-genesis-block/*.block organizations/peerOrganizations organizations/ordererOrganizations
    ## remove fabric ca artifacts
    # rm -rf organizations/fabric-ca/org1/msp organizations/fabric-ca/org1/tls-cert.pem organizations/fabric-ca/org1/ca-cert.pem organizations/fabric-ca/org1/IssuerPublicKey organizations/fabric-ca/org1/IssuerRevocationPublicKey organizations/fabric-ca/org1/fabric-ca-server.db
    # rm -rf organizations/fabric-ca/org2/msp organizations/fabric-ca/org2/tls-cert.pem organizations/fabric-ca/org2/ca-cert.pem organizations/fabric-ca/org2/IssuerPublicKey organizations/fabric-ca/org2/IssuerRevocationPublicKey organizations/fabric-ca/org2/fabric-ca-server.db
    # rm -rf organizations/fabric-ca/ordererOrg/msp organizations/fabric-ca/ordererOrg/tls-cert.pem organizations/fabric-ca/ordererOrg/ca-cert.pem organizations/fabric-ca/ordererOrg/IssuerPublicKey organizations/fabric-ca/ordererOrg/IssuerRevocationPublicKey organizations/fabric-ca/ordererOrg/fabric-ca-server.db


#    rm -rf channel-artifacts log.txt fabcar.tar.gz fabcar

  fi
}




#linux,darwin and version info
OS_ARCH=$(echo "$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
CRYPTO="cryptogen"
MAX_RETRY=5
CLI_DELAY=3
CHANNEL_NAME="mscchannel"

COMPOSE_FILE_BASE=docker/docker-compose-base.yaml

COMPOSE_FILE_COUCH=docker/docker-compose-couch.yaml

COMPOSE_FILE_CA=docker/docker-compose-ca.yaml

CC_SRC_LANGUAGE=javascript
# Chaincode version
VERSION=1
IMAGETAG="latest"
DATABASE="leveldb"


#parseargs
if [[ $# -lt 1 ]] ; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

# parse a createChannel subcommand if used
if [[ $# -ge 1 ]] ; then
  key="$1"
  if [[ "$key" == "createChannel" ]]; then
      export MODE="createChannel"
      shift
  fi
fi

# parse flags

while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  -h )
    printHelp
    exit 0
    ;;
  -c )
    CHANNEL_NAME="$2"
    shift
    ;;
  -ca )
    CRYPTO="Certificate Authorities"
    ;;
  -r )
    MAX_RETRY="$2"
    shift
    ;;
  -d )
    CLI_DELAY="$2"
    shift
    ;;
  -s )
    DATABASE="$2"
    shift
    ;;
  -l )
    CC_SRC_LANGUAGE="$2"
    shift
    ;;
  -v )
    VERSION="$2"
    shift
    ;;
  -i )
    IMAGETAG="$2"
    shift
    ;;
  -verbose )
    VERBOSE=true
    shift
    ;;
  * )
    echo
    echo "Unknown flag: $key"
    echo
    printHelp
    exit 1
    ;;
  esac
  shift
done

# Are we generating crypto material with this command?
if [ ! -d "organizations/peerOrganizations" ]; then
  CRYPTO_MODE="with crypto from '${CRYPTO}'"
else
  CRYPTO_MODE=""
fi

#cmdline
if [ "$MODE" == "up" ]; then
  echo "Starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}' ${CRYPTO_MODE}"
  echo
elif [ "$MODE" == "createChannel" ]; then
  echo "Creating channel '${CHANNEL_NAME}'."
  echo
  echo "If network is not up, starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE} ${CRYPTO_MODE}"
  echo
elif [ "$MODE" == "down" ]; then
  echo "Stopping network"
  echo
elif [ "$MODE" == "restart" ]; then
  echo "Restarting network"
  echo
elif [ "$MODE" == "deployCC" ]; then
  echo "deploying chaincode on channel '${CHANNEL_NAME}'"
  echo
else
  printHelp
  exit 1
fi

if [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "createChannel" ]; then
  createChannel
elif [ "${MODE}" == "deployCC" ]; then
  deployCC
elif [ "${MODE}" == "down" ]; then
  networkDown
elif [ "${MODE}" == "restart" ]; then
  networkDown
  networkUp
else
  printHelp
  exit 1
fi
