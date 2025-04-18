# Minimal Fabric Peer Organization Setup (Org1 with Fabric CA)

## Purpose

This guide explains how to use **standard Hyperledger Fabric tools and the provided scripts** (`start_peers.sh`, `cleanup.sh`) to launch a minimal Fabric setup. The goal is to start the components for a **single peer organization (specifically Org1 in this example)**, using Fabric CA for identities, **without relying on external orchestration tools** then joining Galachain Network. 

This setup creates the foundation for Org1: its Certificate Authority (CA) and its first peer node (`peer0.org1.example.com`). It intentionally **does not** include an ordering service or create a Fabric channel. This makes it suitable for scenarios where you want to independently run your organization's peer(s) and later connect them to an existing, external Fabric network or channel. You would need the connection details (orderer endpoints, channel name, etc.) for that external network separately.

**Note:** While this guide focuses on "Org1" as defined in the standard `test-network`, the principles can be adapted for a different organization name. However, this would require modifying organization names, ports, paths, and potentially function calls within the `start_peers.sh` script, the `registerEnroll.sh` script, and the Docker Compose files (`compose/*.yaml`).


## Prerequisites

Before you begin, ensure you have the following essential tools installed on your system. These are standard requirements for working with Hyperledger Fabric:

1.  **Git:** For cloning repositories (both `fabric-samples` and the repository containing the startup/cleanup scripts).
2.  **cURL:** A command-line tool for transferring data, used by some Fabric installation scripts.
3.  **Docker:** The core containerization platform Fabric runs on. Docker Desktop is a common choice for local development.
    *   [Official Docker Installation Guides](https://docs.docker.com/get-docker/)
4.  **Docker Compose:** A tool for defining and running multi-container Docker applications. Modern Docker versions include this as a plugin (`docker compose`). Older standalone versions (`docker-compose`) also work.
    *   *(Usually included with Docker Desktop)*
5.  **Hyperledger Fabric Binaries and Docker Images:** These are the specific command-line tools (`peer`, `fabric-ca-client`, etc.) and the container images Fabric components run from.
    *   **Crucial Step:** Follow the official "Install Fabric Samples, Binaries, and Docker Images" guide carefully: [Hyperledger Fabric Documentation - Install](https://hyperledger-fabric.readthedocs.io/en/release-2.5/install.html)
    *   Ensure the downloaded versions match the Fabric version you intend to use (e.g., v2.5.x, which is the current LTS).
6.  **Go (Golang) (Optional but Recommended):** Needed if you plan to develop or run chaincode written in Go, or use the Fabric Go SDK.
    *   [Official Go Installation Guide](https://go.dev/doc/install)
7.  **Basic Shell Environment:** A standard command-line environment like bash (common on Linux/macOS) with utilities like `cp`, `mkdir`, `chmod`.

## Setup Steps

These steps assume you have successfully installed all prerequisites.

1.  **Obtain Fabric Samples:** The setup relies on the directory structure, configuration files, and compose files within the `fabric-samples` repository. Clone it if you haven't already. Replace `YOUR_WORKSPACE` with your preferred directory.
    ```bash
    # Navigate to your workspace directory
    cd YOUR_WORKSPACE
    # Clone the repository if you haven't already
    git clone https://github.com/hyperledger/fabric-samples.git
    ```

2.  **Navigate to `test-network`:** The scripts are designed to run from the `test-network` directory within `fabric-samples`.
    ```bash
    cd fabric-samples/test-network
    ```
    *(The rest of the commands assume you are **inside** this `test-network` directory).*

3.  **Obtain and Place Startup/Cleanup Scripts:**
    *   Download or clone the `start_peers.sh` and `cleanup.sh` scripts from the provided GitLab repository into a temporary location or a known directory on your system.
    *   **Copy or move** these two script files **directly inside** your current `test-network` directory. For example, if you downloaded them to your `~/Downloads` folder, you would run these commands *from within the `test-network` directory*:
        ```bash
        # Example commands (replace ~/Downloads if scripts are elsewhere):
        cp ~/Downloads/start_peers.sh .
        cp ~/Downloads/cleanup.sh .
        # OR use 'mv' if you want to move instead of copy
        # mv ~/Downloads/start_peers.sh .
        # mv ~/Downloads/cleanup.sh .
        ```

4.  **Ensure Necessary Support Files are Present:** This setup uses specific scripts and configuration files from the standard `fabric-samples`. If you've modified this directory or performed cleanups before, some might be missing. These commands copy the required files from the standard locations within the main `fabric-samples` directory to where our scripts expect them.

    ```bash
    # Create directories if they don't exist
    mkdir -p organizations/fabric-ca
    mkdir -p config/peer
    mkdir -p organizations # Ensure this parent exists

    # === Copy Scripts ===
    # registerEnroll.sh: Used by Fabric CA to create identities
    cp ../fabric-samples/test-network/organizations/fabric-ca/registerEnroll.sh organizations/fabric-ca/
    # ccp-generate.sh: Creates connection profiles (JSON/YAML)
    cp ../fabric-samples/test-network/organizations/ccp-generate.sh organizations/

    # === Copy Configuration ===
    # core.yaml: Main configuration file for the peer
    cp ../config/peer/core.yaml config/peer/

    # === Verify Permissions ===
    # Make sure the support scripts we copied are executable if needed
    chmod +x organizations/ccp-generate.sh
    # Optional: Ensure utils.sh is executable (usually is by default)
    # chmod +x scripts/utils.sh
    ```
    *(Adjust the source paths (`../...`) if your main `fabric-samples` directory is located elsewhere relative to `test-network`). If the `cp ../config/peer/core.yaml` command fails, the main `config` directory might be missing from your `fabric-samples` clone; ensure you have a complete clone or try alternative sources if necessary).*

5.  **Make Startup/Cleanup Scripts Executable:** Since the scripts are now inside the `test-network` directory, make them executable.
    ```bash
    chmod +x start_peers.sh
    chmod +x cleanup.sh
    ```

6.  **(Recap) Verify `docker-compose-test-net.yaml`:** Double-check that the file `compose/docker/docker-compose-test-net.yaml` within your `test-network` directory contains the necessary `environment` variables (`FABRIC_CFG_PATH`, `CORE_PEER_MSPCONFIGPATH`) and `volumes` for **Org1** as determined during previous troubleshooting. If it's incorrect, update it to match the final correct version provided earlier.

## Running the Org1 Peer Setup

**Note:** The provided `start_peers.sh` script is currently configured specifically for **Org1**. Running it will start `peer0.org1.example.com` and related components.

1.  **Navigate to the `test-network` directory (if not already there):**
    ```bash
    cd YOUR_WORKSPACE/fabric-samples/test-network
    ```

2.  **Run Cleanup (Recommended before first run or if issues occur):** This removes previous containers and artifacts created by these scripts.
    ```bash
    ./cleanup.sh
    ```

3.  **Execute the Startup Script:** This starts the CA and Peer for Org1, using LevelDB by default.
    ```bash
    ./start_peers.sh
    ```

4.  **Optional: Use CouchDB:** If you prefer CouchDB for the peer's state database (enabling rich queries), run with the `-c couchdb` flag:
    ```bash
    ./start_peers.sh -c couchdb
    ```

The script performs the steps outlined previously (starts CAs, enrolls identities for Org1, starts Org1 peer and potentially CouchDB) and verifies the peer is running.

## Verification

After a successful run, check the running Docker containers:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

You should see `peer0.org1.example.com` and `ca_org1` running. Depending on whether you used the `-c couchdb` flag, you may also see `couchdb0`. You will also likely see `ca_org2` and `ca_orderer` running, as they are started by the CA compose file but are not actively used by this script for Org1 operations.

## Component Breakdown

This setup uses fundamental Fabric components:

*   **Fabric CA (`ca_org1`):** The Certificate Authority, responsible for issuing digital identities (certificates) for the organization. Think of it as the ID card issuer for Org1. [Learn More: Fabric CA](https://hyperledger-fabric-ca.readthedocs.io/en/release-1.5/)
*   **Fabric Peer (`peer0.org1.example.com`):** The main node for Org1. It holds a copy of the transaction history (ledger), runs business logic (chaincode), and participates in the transaction validation process. [Learn More: Peers](https://hyperledger-fabric.readthedocs.io/en/release-2.5/peers/peers.html)
*   **MSP (Membership Service Provider):** Not a running component, but the *set of folders and certificates* generated by the CA (e.g., under `organizations/peerOrganizations/org1.example.com/`) that define Org1's identity and structure. [Learn More: MSP](https://hyperledger-fabric.readthedocs.io/en/release-2.5/msp.html)
*   **State Database (LevelDB or CouchDB):** The database where the current state of the ledger (world state) is stored.
    *   **LevelDB (Default):** An embedded key-value store running *inside* the peer container. No separate container.
    *   **CouchDB (`couchdb0` - Optional):** An external JSON document database running in its own container (`couchdb0`), enabling rich queries. [Learn More: CouchDB as State Database](https://hyperledger-fabric.readthedocs.io/en/release-2.5/couchdb_as_state_database.html)

For a broad overview of how these fit together: [Hyperledger Fabric Concepts](https://hyperledger-fabric.readthedocs.io/en/release-2.5/key_concepts.html)

### What is NOT Included?

*   **Ordering Service:** This setup lacks the crucial component that orders transactions into blocks. This must be provided by the external network you connect to. [Learn More: The Ordering Service](https://hyperledger-fabric.readthedocs.io/en/release-2.5/orderer/ordering_service.html)
*   **Other Organizations:** Only Org1 components are started.
*   **Channels:** No application channels are created by this script. [Learn More: Channels](https://hyperledger-fabric.readthedocs.io/en/release-2.5/channels.html)

## Next Steps: Joining an External Channel

Now that your Org1 peer (`peer0.org1.example.com`) is running and has its identity configured:

1.  **Gather Information:** You need details about the channel you want to join from the network administrators:
    *   Orderer endpoint(s) address(es) (e.g., `orderer.otherdomain.com:7050`)
    *   Orderer organization's TLS CA root certificate(s).
    *   The exact name of the channel.
    *   Either the channel's Genesis Block or a recent Channel Configuration Block.
2.  **Use `peer channel` commands:** Execute commands *inside* the running peer container using `docker exec`.
    *   Fetch the channel configuration block using `peer channel fetch config`.
    *   Join the channel using `peer channel join -b <fetched_block_file>`.
    *   **Reference:** [Joining a Peer to a Channel Tutorial](https://hyperledger-fabric.readthedocs.io/en/release-2.5/channel_update_tutorial.html) (Focus on Step 1: Fetch Config Block and Step 3: Join Peer). You'll need to adapt the commands to run via `docker exec peer0.org1.example.com ...` and use the correct paths and environment variables within the container.

## Cleanup

To stop and remove the Org1 components launched by `start_peers.sh`, use the cleanup script:

```bash
./cleanup.sh