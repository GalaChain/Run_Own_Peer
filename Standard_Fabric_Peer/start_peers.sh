#!/usr/bin/env bash
#
# Script to bring up only Fabric Peer and CA for Org1 in test-network

ROOTDIR=$(cd "$(dirname "$0")" && pwd)
export PATH=${ROOTDIR}/../bin:${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false

# push to the required directory & set a trap to go back if needed
pushd ${ROOTDIR} > /dev/null
trap "popd > /dev/null" EXIT

. scripts/utils.sh

: ${CONTAINER_CLI:="docker"}

# --- Detect docker compose version ---
# Try V1 first by executing its version command
if ${CONTAINER_CLI}-compose --version > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
    infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE} (v1)"
# If V1 fails, try V2 by executing its version command
elif ${CONTAINER_CLI} compose version > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
    infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE} (v2)"
else
    # Neither command succeeded
    errorln "Docker Compose (either \`${CONTAINER_CLI}-compose\` or \`${CONTAINER_CLI} compose\` plugin) is required but not found."
    errorln "Please ensure Docker and an appropriate Docker Compose version are installed and in your PATH."
    exit 1
fi
# --- End Docker Compose Detection ---

# --- Determine Docker Socket Path ---
# Get docker sock path from environment variable DOCKER_HOST or default
SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
# Remove unix:// prefix if present (common in DOCKER_HOST)
DOCKER_SOCK="${SOCK##unix://}"
infoln "Using Docker Socket: ${DOCKER_SOCK}"
# --- End Docker Socket Path ---

# Default Peer Database
DATABASE="leveldb"

# Parse command-line options
while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  -h )
    # printHelp function would need to be added or copied from network.sh if needed
    echo "Usage: start_peers_org1.sh [-c <dbtype>] [-verbose]"
    exit 0
    ;;
  -c )
    DATABASE="couchdb"
    shift
    ;;
  -verbose )
    VERBOSE=true
    shift
    ;;
  * )
    errorln "Unknown flag: $key"
    # printHelp
    exit 1
    ;;
  esac
  shift
done


COMPOSE_FILE_CA="compose-ca.yaml"
COMPOSE_FILE_BASE="compose-test-net.yaml"
COMPOSE_FILE_COUCH="compose-couch.yaml"
CONTAINER_CLI_VERSION=$(${CONTAINER_CLI} --version | sed -e 's/.* version //g' | cut -d '.' -f1)

# Check if organization crypto material already exists
if [ -d "organizations/peerOrganizations/org1.example.com" ]; then
  infoln "Org1 crypto material already exists, skipping CA start and identity generation."
else
  # Start CAs (starts all CAs defined in the file, but we only use Org1's)
  infoln "Starting Fabric CAs using compose/compose-ca.yaml"
  # Base CA compose file path - Use only this one since docker specific is empty
  COMPOSE_CA_FILES="-f compose/${COMPOSE_FILE_CA}"

  # --- Debugging ---
  pwd # Print current directory
  echo "--- Running CA compose command ---"
  echo "Command: DOCKER_SOCK='${DOCKER_SOCK}' ${CONTAINER_CLI_COMPOSE} ${COMPOSE_CA_FILES} up -d"
  echo "---------------------------------"
  # --- End Debugging ---

  # Execute docker compose up for CAs
  DOCKER_SOCK="${DOCKER_SOCK}" ${CONTAINER_CLI_COMPOSE} ${COMPOSE_CA_FILES} up -d 2>&1
  if [ $? -ne 0 ]; then
      errorln "Failed to execute docker compose up for CAs. Check compose file syntax and Docker engine status."
      docker ps -a # Show container status
      exit 1
  fi
  # Give containers a moment to initialize even before checking file
  infoln "Waiting 5 seconds for CA containers to potentially initialize..."
  sleep 5

  # --- Debugging: Check host directory immediately after 'up' ---
  echo "--- Checking host directory contents ---"
  ls -la organizations/fabric-ca/org1/
  echo "--------------------------------------"
  # --- End Debugging ---

  # Enroll and Register Identities for Org1
  . organizations/fabric-ca/registerEnroll.sh

  # Wait for Org1 CA to be ready
  infoln "Waiting for Org1 CA certificate (organizations/fabric-ca/org1/tls-cert.pem)..."
  MAX_RETRY=30
  COUNTER=0
  while [ $COUNTER -lt $MAX_RETRY ]; do
    if [ -f "organizations/fabric-ca/org1/tls-cert.pem" ]; then
      infoln "Org1 CA certificate found."
      break
    fi
    COUNTER=$((COUNTER + 1))
    echo "Waiting... (${COUNTER}/${MAX_RETRY})"
    # Optional: Check container status within loop
    # docker ps -a --filter name=ca_org1 --filter status=running -q || { errorln "ca_org1 container stopped unexpectedly!"; exit 1; }
    sleep 2 # Wait 2 seconds between checks
  done

  if [ ! -f "organizations/fabric-ca/org1/tls-cert.pem" ]; then
     errorln "Timeout waiting for organizations/fabric-ca/org1/tls-cert.pem"
     errorln "Please check Docker volume mounts, file permissions, and ca_org1 container logs ('docker logs ca_org1')."
     exit 1
  fi

  infoln "Creating Org1 Identities"
  createOrg1

  infoln "Generating CCP file for Org1"
  ./organizations/ccp-generate.sh 2>/dev/null # This script generates for both, ignore errors for Org2
fi

# --- Add Delay ---
infoln "Waiting 10 seconds before starting peer to ensure filesystem sync..."
sleep 10
# --- End Delay ---

# Start Peer for Org1
infoln "Starting Fabric Peer for Org1"

# Construct path for the primary CLI-specific Peer compose file
CLI_SPECIFIC_BASE_FILE="compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_BASE}"

# Check if the required CLI-specific file exists
if [ ! -f "${CLI_SPECIFIC_BASE_FILE}" ]; then
     errorln "Required CLI-specific compose file not found at ${CLI_SPECIFIC_BASE_FILE}. Cannot start peer."
     exit 1
fi

# Use ONLY the CLI-specific file for starting the peer
PEER_COMPOSE_FILES="-f ${CLI_SPECIFIC_BASE_FILE}"
PEER_SERVICES="peer0.org1.example.com"

# Add CouchDB if selected (assuming CouchDB definitions are compatible or also in the override file)
if [ "${DATABASE}" == "couchdb" ]; then
    # Check if CouchDB override file exists
    CLI_SPECIFIC_COUCH_FILE="compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
    if [ ! -f "${CLI_SPECIFIC_COUCH_FILE}" ]; then
        errorln "CouchDB selected, but CLI-specific CouchDB compose file not found at ${CLI_SPECIFIC_COUCH_FILE}."
        # Optional: could try adding the base couch file, but might conflict
        # PEER_COMPOSE_FILES="${PEER_COMPOSE_FILES} -f compose/${COMPOSE_FILE_COUCH}"
        exit 1
    else
        PEER_COMPOSE_FILES="${PEER_COMPOSE_FILES} -f ${CLI_SPECIFIC_COUCH_FILE}"
    fi
    PEER_SERVICES="${PEER_SERVICES} couchdb0"
fi

# Export DOCKER_SOCK so compose file can substitute it
export DOCKER_SOCK
${CONTAINER_CLI_COMPOSE} ${PEER_COMPOSE_FILES} up -d ${PEER_SERVICES} 2>&1
# Unset DOCKER_SOCK if desired after the command, although usually not necessary
# unset DOCKER_SOCK

# Check if peer container is running
infoln "Checking if peer0.org1.example.com is running..."
sleep 3 # Give it a moment
if ! docker ps -a --filter name=peer0.org1.example.com --filter status=running -q | grep -q .; then
    errorln "peer0.org1.example.com container failed to start or exited."
    errorln "Please check peer logs: docker logs peer0.org1.example.com"
    exit 1
fi

successln "Successfully started Fabric Peer and CA for Org1"
exit 0