#!/usr/bin/env bash
#
# Script to comprehensively clean up the Fabric test network environment

echo "Stopping and removing containers..."
# Stop all typical test-network containers
docker stop ca_org1 ca_org2 ca_orderer peer0.org1.example.com peer0.org2.example.com orderer.example.com couchdb0 couchdb1 2>/dev/null || true
# Remove all typical test-network containers
docker rm -f ca_org1 ca_org2 ca_orderer peer0.org1.example.com peer0.org2.example.com orderer.example.com couchdb0 couchdb1 2>/dev/null || true
# Remove any chaincode (dev) containers
docker rm -f $(docker ps -aq --filter "name=dev-peer*") 2>/dev/null || true

echo "Removing chaincode images..."
docker rmi -f $(docker images -aq --filter "reference=dev-peer*") 2>/dev/null || true

echo "Removing generated organizations and artifacts..."
# Remove generated crypto material for peers and orderers
rm -rf organizations/peerOrganizations/
rm -rf organizations/ordererOrganizations/
# Remove generated CA server data (but not registerEnroll.sh if present)
rm -rf organizations/fabric-ca/org1/
rm -rf organizations/fabric-ca/org2/
rm -rf organizations/fabric-ca/ordererOrg/
# Remove channel artifacts and other generated files
rm -rf channel-artifacts/
rm -rf system-genesis-block/
rm -f log.txt *.tar.gz *.block *.pb *.json

echo "Removing docker volumes..."
docker volume rm peer0.org1.example.com peer0.org2.example.com orderer.example.com 2>/dev/null || true

echo "Removing docker network..."
docker network rm fabric_test 2>/dev/null || true

echo "Cleanup complete."
exit 0