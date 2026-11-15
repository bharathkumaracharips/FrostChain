# Threat Model & Protocol Invariants

## 1. Threat Vectors and Mitigations

| Threat Vector | Attack Scenario | Protocol Mitigation |
|---|---|---|
| **Sensor Spoofing** | Rogue actor injects fake valid temperatures via MQTT | Devices have unique ECDSA / Ed25519 keypairs loaded into secure element. Every message requires a valid cryptographic signature over `(shipmentId, seqNo, temp, timestamp)`. |
| **Replay Attack** | Carrier intercepts previous good reading and replays it during a cooling failure | Sequential monotonic counter (`seqNo`) and timestamp validation: Readings with duplicate sequence numbers or old timestamps are rejected. |
| **Telemetry Suppression (Offline Attack)** | Carrier turns off IoT tracker during a refrigeration breakdown and turns it back on once cold | Missing telemetry penalty: If the gap between readings exceeds `maxAllowedMissingInterval` (e.g. 2 hours), the system treats the missing interval as an active excursion unless offline flash buffer is provided with continuous sequence numbers. |
| **Device Tampering / Swapping** | Carrier moves tracker to a different refrigerated box while the main shipment sits at room temperature | Device is cryptographically bound to single active shipment in `DeviceRegistry.sol`. Tamper-evident seal attestations and chain-of-custody checks at handover. |
| **Premature Escrow Settlement** | Carrier triggers settlement before excursions are processed or during an open dispute | `SettlementManager.sol` checks delivery confirmation from receiver AND validates that all pending penalty proposals and dispute challenge periods have elapsed. |
| **Malicious Carrier Dispute** | Carrier opens fraudulent dispute to delay payment or penalties | Dispute bond requirement: disputing party must post a bond that is slashed if the dispute is found frivolous. |

---

## 2. Protocol Invariants
1. `INV-1`: Every shipment has a globally unique identifier (`bytes32`).
2. `INV-2`: Only the registered device currently assigned to an active shipment can produce valid attestations.
3. `INV-3`: Once a shipment is activated, its assigned `TemperaturePolicy` is completely immutable.
4. `INV-4`: Escrow payouts can never exceed total funds deposited in `ShipmentEscrow.sol`.
5. `INV-5`: Merkle proofs for excursion evidence must anchor to a verified on-chain root in `AttestationAnchor.sol`.
6. `INV-6`: No settlement can execute while a dispute is actively pending resolution.
