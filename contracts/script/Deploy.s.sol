// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShipmentRegistry} from "../src/ShipmentRegistry.sol";
import {DeviceRegistry} from "../src/DeviceRegistry.sol";
import {TemperaturePolicyManager} from "../src/TemperaturePolicyManager.sol";
import {AttestationAnchor} from "../src/AttestationAnchor.sol";
import {ShipmentEscrow} from "../src/ShipmentEscrow.sol";
import {PenaltyEngine} from "../src/PenaltyEngine.sol";
import {SettlementManager} from "../src/SettlementManager.sol";
import {ChainOfCustody} from "../src/ChainOfCustody.sol";

contract DeployScript {
    struct DeploymentResult {
        address shipmentRegistry;
        address deviceRegistry;
        address policyManager;
        address attestationAnchor;
        address shipmentEscrow;
        address penaltyEngine;
        address settlementManager;
        address chainOfCustody;
    }

    function run() external returns (DeploymentResult memory result) {
        address deployer = msg.sender;

        // 1. Deploy Registries
        ShipmentRegistry shipmentReg = new ShipmentRegistry(deployer);
        DeviceRegistry deviceReg = new DeviceRegistry(deployer);
        TemperaturePolicyManager policyMgr = new TemperaturePolicyManager();
        AttestationAnchor anchor = new AttestationAnchor(deployer);

        // 2. Deploy Escrow & Penalty Engine
        ShipmentEscrow escrow = new ShipmentEscrow(address(0)); // Updated after settlement manager deploy
        PenaltyEngine penalty = new PenaltyEngine(address(policyMgr));

        // 3. Deploy Settlement Manager & Chain of Custody
        SettlementManager settlement = new SettlementManager(
            address(shipmentReg),
            address(escrow),
            address(penalty)
        );
        escrow.setSettlementManager(address(settlement));

        ChainOfCustody custody = new ChainOfCustody(address(shipmentReg));

        // 4. Seed Standard Temperature Policy: Vaccine (2°C - 8°C)
        bytes32 vaccinePolicyId = keccak256("VACCINE_POLICY_V1");
        policyMgr.createPolicy(
            vaccinePolicyId,
            "Standard Vaccine Biologics (2°C to 8°C)",
            200,   // +2.00°C
            800,   // +8.00°C
            1800,  // 30 min continuous grace period
            7200,  // 2 hr cumulative
            0,     // 0.00°C critical freezing spoilage
            1500,  // +15.00°C critical heat spoilage
            100000000000000 // 0.0001 ETH/sec base penalty
        );

        result = DeploymentResult({
            shipmentRegistry: address(shipmentReg),
            deviceRegistry: address(deviceReg),
            policyManager: address(policyMgr),
            attestationAnchor: address(anchor),
            shipmentEscrow: address(escrow),
            penaltyEngine: address(penalty),
            settlementManager: address(settlement),
            chainOfCustody: address(custody)
        });
    }
}
