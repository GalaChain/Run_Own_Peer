# Galachain — External‑Organization On‑Boarding 

> **Purpose:** Outline, at architecture level, how an external organization (“Partner Org”) provisions its own Fabric peers and attaches to the existing **Galachain asset-channel** 
> **Provisioning Surface:** **Chainlaunch Web GUI** only (no CLI syntax).  

---

## 🔗 Primary References

| Topic | Documentation |
|-------|---------------|
| Chainlaunch – Getting Started | <https://docs.chainlaunch.dev/getting-started> |
| Chainlaunch – Architecture | <https://docs.chainlaunch.dev/architecture> |
| Phase 1 – Create Org | <https://docs.chainlaunch.dev/guides/create-org> |
| Phase 2 – Create Nodes | <https://docs.chainlaunch.dev/guides/create-nodes> |

---

## 1 · Define Your Fabric Organization (Phase 1)

- In Chainlaunch GUI, open **Organizations → Create**.  
- Enter **Org Name**, **MSP ID**, and public domain.  
- Chainlaunch autogenerates admin identities and stores crypto in the workspace vault.

---

## 2 · Provision Peer Nodes (Phase 2)

- Navigate to **Nodes → Bulk Create**: choose peer count, CPU/RAM, region/VPC.  
- After provisioning, the dashboard displays for each peer:  
  - **Static public IP / DNS**  
  - **TLS server certificate**  
- Record the public IPs and TLS certs for the Gala integration step.

---

## 3 · Exchange Artifacts with Gala

| You ➜ Gala | Gala ➜ You |
|------------|-----------|
| Public IPs for every peer | Confirmation that your IPs are whitelisted  **Orderer endpoint map** + **orderer TLS CA cert** |
| TLS certs for each peer | Gala appends the information in the channel config |
|Append the orderer information and mapping when importing the chanel| **Orderer endpoint map** + **orderer TLS CA cert** ||

Gala inserts the respective `PARTNERORGMSP` into the channel config and notifies when ready for join.

---

## 4 · Join the Galachain Channel via Chainlaunch “Import Network”

1. In the workspace, open **Networks → Import Network**.  
2. Supply:  
   - **Peer Mapping / Orderer Address Overrides** – Override orderer endpoints with new endpoints given by gala 
   - **Channel Name** (provided by Gala).  
   - **Orderer Endpoints** (host:port list).  
   - **Orderer TLS CA** (upload file).  
3. Click **Import**. Chainlaunch automatically:  
   - Fetches the **genesis block** from the orderer.  
   - Distributes it to all selected peers.  
   - Applies the address overrides, joins peers to the channel, and starts block synchronization.  
4. Dashboard status turns **“Synced”** once ledger height matches Galachain.

---

## 5 · Post‑Join Observability & Operations (all in Chainlaunch GUI)

| View | Purpose |
|------|---------|
| **Nodes → Peer Logs** | Verify successful join and continuous block pulls. |
| **Channels → <galachain‑channel>** | Inspect channel membership and health. |
| **Blocks** (real‑time explorer) | Confirm new blocks arrive and ledger height advances. |
| **Upgrade wizard** | Align Fabric patch level with Gala when notified. |



Partner Org is now an active member of the **Galachain asset channel** channel, able to currently read blocks. 

---
