#!/bin/bash

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp_1 {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template_1.json
}

function yaml_ccp_1 {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template_1.yaml | sed -e $'s/\\\\n/\\\n        /g'
}

function json_ccp_2 {
    local PP=$(one_line_pem $5)
    local CP=$(one_line_pem $6)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${P1PORT}/$3/" \
        -e "s/\${CAPORT}/$4/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template_2.json 
}

function yaml_ccp_2 {
    local PP=$(one_line_pem $5)
    local CP=$(one_line_pem $6)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${P1PORT}/$3/" \
        -e "s/\${CAPORT}/$4/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template_2.yaml | sed -e $'s/\\\\n/\\\n        /g'
}

function json_ccp_3 {
    local PP=$(one_line_pem $6)
    local CP=$(one_line_pem $7)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${P1PORT}/$3/" \
        -e "s/\${P2PORT}/$4/" \
        -e "s/\${CAPORT}/$5/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template_3.json 
}

function yaml_ccp_3 {
    local PP=$(one_line_pem $5)
    local CP=$(one_line_pem $6)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${P1PORT}/$3/" \
        -e "s/\${P2PORT}/$4/" \
        -e "s/\${CAPORT}/$5/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template_3.yaml | sed -e $'s/\\\\n/\\\n        /g'
}


ORG=1
P0PORT=7051
P1PORT=7061
CAPORT=7054
PEERPEM=organizations/peerOrganizations/org1.msc.com/tlsca/tlsca.org1.msc.com-cert.pem
CAPEM=organizations/peerOrganizations/org1.msc.com/ca/ca.org1.msc.com-cert.pem

echo "$(json_ccp_2 $ORG $P0PORT $P1PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/org1.msc.com/connection-org1.json
echo "$(yaml_ccp_2 $ORG $P0PORT $P1PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/org1.msc.com/connection-org1.yaml

ORG=2
P0PORT=8051
CAPORT=8054
PEERPEM=organizations/peerOrganizations/org2.msc.com/tlsca/tlsca.org2.msc.com-cert.pem
CAPEM=organizations/peerOrganizations/org2.msc.com/ca/ca.org2.msc.com-cert.pem

echo "$(json_ccp_1 $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/org2.msc.com/connection-org2.json
echo "$(yaml_ccp_1 $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/org2.msc.com/connection-org2.yaml



ORG=3
P0PORT=9051
P1PORT=9061
P2PORT=9071
CAPORT=9054
PEERPEM=organizations/peerOrganizations/org3.msc.com/tlsca/tlsca.org3.msc.com-cert.pem
CAPEM=organizations/peerOrganizations/org3.msc.com/ca/ca.org3.msc.com-cert.pem

echo "$(json_ccp_3 $ORG $P0PORT $P1PORT $P2PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/org3.msc.com/connection-org3.json
echo "$(yaml_ccp_3 $ORG $P0PORT $P1PORT $P2PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/org3.msc.com/connection-org3.yaml