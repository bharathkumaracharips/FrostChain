// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShipmentRegistry} from "../src/ShipmentRegistry.sol";
import {DeviceRegistry} from "../src/DeviceRegistry.sol";
import {TemperaturePolicyManager} from "../src/TemperaturePolicyManager.sol";
import {AttestationAnchor} from "../src/AttestationAnchor.sol";
import {ShipmentEscrow} from "../src/ShipmentEscrow.sol";
import {PenaltyEngine} from "../src/PenaltyEngine.sol";
import {SettlementManager} from "../src/SettlementManager.sol";
import {IShipmentRegistry} from "../src/interfaces/IShipmentRegistry.sol";
import {IPenaltyEngine} from "../src/interfaces/IAttestationAnchor.sol";

contract FrostChainLifecycleTest {
    ShipmentRegistry private shipmentReg;
    DeviceRegistry private deviceReg;
    TemperaturePolicyManager private policyMgr;
    AttestationAnchor private anchor;
    ShipmentEscrow private escrow;
    PenaltyEngine private penalty;
    SettlementManager private settlement;

    bytes32 private policyId;
    bytes32 private shipmentId;
    address private carrier = address(0x2222222222222222222222222222222222222222);
    address private receiver = address(0x3333333333333333333333333333333333333333);

    function setUp() public {
        shipmentReg = new ShipmentRegistry(address(this));
        deviceReg = new DeviceRegistry(address(this));
        policyMgr = new TemperaturePolicyManager();
        anchor = new AttestationAnchor(address(this));
        escrow = new ShipmentEscrow(address(0));
        penalty = new PenaltyEngine(address(policyMgr));

        settlement = new SettlementManager(
            address(shipmentReg),
            address(escrow),
            address(penalty)
        );
        escrow.setSettlementManager(address(settlement));

        policyId = keccak256("VACCINE_POLICY");
        policyMgr.createPolicy(
            policyId,
            "Vaccine 2C-8C",
            200,
            800,
            600, // 10 min grace period
            3600,
            0,
            1500,
            1000 // penalty per second
        );

        shipmentId = keccak256("SHIPMENT_001");
    }

    function testShipmentAndEscrowSettlement() public {
        // 1. Create shipment
        shipmentReg.createShipment(
            shipmentId,
            carrier,
            receiver,
            policyId,
            "Vaccine Vials",
            "Pfizer Facility A",
            "Central Hospital Warehouse"
        );

        // 2. Fund Escrow: service fee 2 ether + penalty reserve 1 ether = 3 ether
        escrow.fundEscrow{value: 3 ether}(shipmentId, 1 ether);

        // 3. Transition to Delivered
        shipmentReg.updateStatus(shipmentId, IShipmentRegistry.ShipmentStatus.InTransit);
        shipmentReg.updateStatus(shipmentId, IShipmentRegistry.ShipmentStatus.Delivered);

        // 4. Record an Excursion: 20 minutes (1200 seconds) at 10.00°C (1000 centi-degrees)
        // Excess seconds = 1200 - 600 = 600 seconds. Base = 600 * 1000 = 600,000.
        // Severity = (100 + (1000 - 800)) / 100 = 300 / 100 = 3. Penalty = 1,800,000 wei.
        IPenaltyEngine.ExcursionEvent memory exc = IPenaltyEngine.ExcursionEvent({
            minRecordedTemp: 200,
            maxRecordedTemp: 1000,
            durationSeconds: 1200,
            criticalSpoilage: false
        });

        settlement.recordExcursionPenalty(shipmentId, exc, 1 ether);
        uint256 assessed = settlement.assessedPenalties(shipmentId);
        require(assessed > 0, "Penalty must be computed");

        // 5. Execute settlement
        settlement.settleShipment(shipmentId);

        IShipmentRegistry.Shipment memory s = shipmentReg.getShipment(shipmentId);
        require(s.status == IShipmentRegistry.ShipmentStatus.Settled, "Must be settled");
    }

    receive() external payable {}
}
