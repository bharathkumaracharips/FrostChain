# System Architecture: Cold-Chain Monitoring DApp
**Platform:** EVM Blockchain + Authenticated IoT Edge + Smart Contract Escrow  
**Target:** Pharmaceuticals, Vaccines, Perishables, and Cold-Storage Logistics  

---

## 1. System Overview & Core Participants

```
       +-------------------------------------------------------------------------+
       |                        SMART CONTRACT ECOSYSTEM (EVM)                   |
       |  ShipmentRegistry  |  DeviceRegistry  |  TemperaturePolicyManager       |
       |  AttestationAnchor |  ShipmentEscrow  |  PenaltyEngine  |  Settlement   |
       +-------------------------------------------------------------------------+
                    ^                       ^                      ^
                    | Merkle Roots          | Escrow Deposits      | Payout / Penalties
                    |                       |                      |
       +------------+-----------+  +--------+--------+  +----------+----------+
       |   ATTESTATION ANCHOR   |  | SHIPMENT OWNER  |  | LOGISTICS PROVIDER  |
       |  (Merkle Batch Engine) |  |   (Shipper)     |  |     (Carrier)       |
       +------------+-----------+  +-----------------+  +---------------------+
                    ^
                    | 4. Signed Attestation Batches & Excursion Reports
                    |
       +------------+----------------------------------------------------+
       |                  RUST BACKEND & TELEMETRY ENGINE                 |
       |    - MQTT / HTTPS Ingestion Gateway with Signature Verification |
       |    - Continuous & Cumulative Excursion Monitor                  |
       |    - Real-Time Alerts (Webhooks, Email, In-App)                 |
       |    - Historical Telemetry Database (PostgreSQL Time-Series)     |
       +--------------------+--------------------------------------------+
                            ^
                            | 3. MQTT Signed Telemetry (JSON/CBOR)
                            |    Every 30-60s (with offline flash buffering)
                            |
       +--------------------+--------------------------------------------+
       |                  IOT EDGE HARDWARE & FIRMWARE                   |
       |    - Microcontroller: ESP32-WROOM-32 / Cellular/Wi-Fi           |
       |    - Sensor: DS18B20 (1-Wire digital) / SHT31 (I2C)             |
       |    - Crypto: Secp256k1 / Ed25519 Device Key in Secure Storage   |
       |    - Measurement: temperature, humidity, seqNo, timestamp       |
       +-----------------------------------------------------------------+
```

---

## 2. End-to-End Shipment Lifecycle
1. **Shipment Creation:** Shipper registers shipment with origin, destination, carrier address, and receiver address in `ShipmentRegistry.sol`.
2. **Policy Binding:** A temperature policy is assigned (e.g. `VACCINE_POLICY`: 2.00°C to 8.00°C, max continuous excursion 30 min, penalty multiplier \$50/min) in `TemperaturePolicyManager.sol`.
3. **Escrow Funding:** Shipper deposits logistics payment + carrier puts up collateral into `ShipmentEscrow.sol`.
4. **Device Authorization:** An active, calibrated IoT device (`DeviceRegistry.sol`) is bound to the shipment.
5. **In-Transit Telemetry:**
   - The device samples temperature every 30 seconds.
   - Each measurement is signed with the device private key: $\sigma = \text{Sign}_{sk}(\text{shipmentId} \parallel \text{seqNo} \parallel \text{temp} \parallel \text{timestamp})$.
   - Transmitted via MQTT to the Rust Ingestion Gateway.
   - If offline, measurements are buffered in SPI flash memory and flushed with sequence continuity upon reconnection.
6. **Excursion Detection & Alerting:** The Rust `TemperatureMonitor` evaluates breach conditions in real-time. If temperature exceeds thresholds, instant alerts are dispatched to shipper and carrier.
7. **On-Chain Anchoring:** Every 50 readings or 1 hour, a Merkle tree of attestation hashes is published on-chain to `AttestationAnchor.sol`.
8. **Handover & Delivery:** Upon arrival, receiver signs custody acceptance in `ChainOfCustody.sol`.
9. **Automated Settlement:**
   - If no excursions: Full escrow released to logistics carrier.
   - If excursions confirmed: `PenaltyEngine.sol` computes exact deductions; penalties refunded to shipper, remainder to carrier.
   - In case of disputes: `DisputeManager.sol` allows arbitrator review before fund release.
