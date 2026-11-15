# ColdGuard: Decentralized Cold-Chain Monitoring DApp (`cold-chain-monitoring`)

![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?style=for-the-badge&logo=solidity)
![Foundry](https://img.shields.io/badge/Foundry-Framework-orange?style=for-the-badge)
![Rust](https://img.shields.io/badge/Rust-Axum%20Backend-black?style=for-the-badge&logo=rust)
![IoT ESP32](https://img.shields.io/badge/IoT-ESP32%20%7C%20DS18B20-cyan?style=for-the-badge)
![Next.js](https://img.shields.io/badge/Next.js-14%20App%20Router-black?style=for-the-badge&logo=next.js)

An enterprise-grade, IoT-driven cold-chain monitoring platform combining **cryptographically signed sensor telemetry**, **on-chain Merkle batch attestations**, and **automated smart contract escrow settlements** with contractual penalty enforcement for temperature-sensitive shipments.

---

## 1. System Overview & Architecture

```
                                +-----------------------------------------------+
                                |        SMART CONTRACT ECOSYSTEM (EVM)         |
                                |  ShipmentRegistry  |  DeviceRegistry          |
                                |  AttestationAnchor |  ShipmentEscrow.sol      |
                                |  PenaltyEngine     |  SettlementManager       |
                                +-----------------------------------------------+
                                           ^                             ^
                                           | Merkle Batches              | Automated Payouts
                                           | & Excursions                | & Penalties
                 +-------------------------+                             +-----------------------+
                 |                                                                               |
       +---------v---------+                                                           +---------v---------+
       |   RUST BACKEND    |                                                           | LOGISTICS CARRIER |
       |  Ingestion Engine |                                                           |   (Transporter)   |
       |  Excursion Alerts |                                                           +---------+---------+
       +---------+---------+                                                                     ^
                 ^                                                                               |
                 | Signed MQTT Telemetry                                                         | Escrow Agreement
                 | (SeqNo, Temp, Sig)                                                            |
       +---------+---------+                                                           +---------+---------+
       |   ESP32 TRACKER   |                                                           |  SHIPMENT OWNER   |
       | DS18B20 / SHT31   |                                                           |  (Pharmaceutical) |
       +-------------------+                                                           +-------------------+
```

---

## 2. Directory Structure

```
cold-chain-monitoring/
├── contracts/                  # Foundry Solidity smart contracts
│   ├── src/
│   │   ├── interfaces/         # Standard interfaces & custom errors
│   │   ├── ShipmentRegistry.sol         # Shipment lifecycle & metadata
│   │   ├── DeviceRegistry.sol           # IoT device keys & assignment
│   │   ├── TemperaturePolicyManager.sol # Vaccine, Frozen, and CRT policies
│   │   ├── AttestationAnchor.sol        # Merkle tree batch anchoring
│   │   ├── ShipmentEscrow.sol           # Service fee & penalty reserve escrow
│   │   ├── PenaltyEngine.sol            # Deterministic penalty calculation
│   │   ├── SettlementManager.sol        # Payout and refund distributions
│   │   └── ChainOfCustody.sol           # Custody handover timestamps
│   ├── test/ColdChainLifecycle.t.sol    # Unit & invariant test suites
│   ├── script/Deploy.s.sol              # Automated deployment script
│   └── foundry.toml
├── firmware/esp32/             # Embedded Rust firmware for ESP32 & DS18B20
│   └── src/main.rs
├── backend/                    # Rust backend workspace (Axum + Tokio)
│   ├── Cargo.toml
│   └── crates/
│       ├── core-telemetry/     # Signed readings, Merkle batcher, excursion logic
│       └── server/             # REST & MQTT ingestion gateway API
├── packages/sdk-ts/            # TypeScript SDK (@coldchain/sdk)
├── frontend/                   # Next.js 14 App Router interactive UI
└── specs/                      # Architecture, policies, and threat models
    ├── architecture.md         # End-to-end data flow & participants
    ├── temperature-policies.md # Fixed-point Celsius & penalty formulae
    └── threat-model.md         # Sensor spoofing, anti-replay, offline buffering
```

---

## 3. Core Capabilities

### 3.1 Fixed-Point Celsius Encoding
All sensor readings and contract thresholds use signed 16-bit integers ($int16$) in centi-degrees Celsius ($\times 100$):
- $+2.00^\circ\text{C} = 200$
- $+8.00^\circ\text{C} = 800$
- $-20.00^\circ\text{C} = -2000$

### 3.2 Automated Penalty Engine
When temperatures exceed safe boundaries beyond the allowable continuous grace period:
$$\text{Penalty} = \min\left(\text{EscrowPenaltyReserve}, \sum (\text{OverrunSeconds} \times \text{BaseRate} \times \text{SeverityMultiplier})\right)$$
If a critical spoilage threshold is violated (e.g. freezing breach on protein vaccines), 100% of the penalty reserve is refunded to the shipper.

### 3.3 Merkle Batch Anchoring
Instead of committing every high-frequency sensor reading on-chain (cost-prohibitive), readings are signed at the edge, collected into batches of 50-100 readings, and anchored as Merkle roots in `AttestationAnchor.sol` with IPFS evidence reports.

---

## 4. Quickstart Guide

### 4.1 Smart Contracts (Foundry)
```bash
cd cold-chain-monitoring/contracts
forge test
forge script script/Deploy.s.sol --broadcast
```

### 4.2 Rust Telemetry Ingestion Server
```bash
cd cold-chain-monitoring/backend
cargo run -p server
# Ingestion API running at http://localhost:8082
```

### 4.3 Next.js Frontend
```bash
cd cold-chain-monitoring/frontend
npm install
npm run dev
# Open http://localhost:3000 to launch the Live Telemetry & Escrow Dashboard
```

---

## 5. Critical Invariants
- `INV-1`: Every shipment has a globally unique identifier.
- `INV-2`: Only registered, active devices can submit accepted telemetry.
- `INV-3`: Once a shipment departs, its temperature policy is permanently immutable.
- `INV-4`: Escrow payouts can never exceed total deposited funds.
- `INV-5`: Settlement cannot execute while a dispute is pending resolution.
