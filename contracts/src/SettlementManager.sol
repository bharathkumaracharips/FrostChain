// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISettlementManager} from "./interfaces/IAttestationAnchor.sol";
import {IShipmentRegistry} from "./interfaces/IShipmentRegistry.sol";
import {IShipmentEscrow} from "./interfaces/IAttestationAnchor.sol";
import {IPenaltyEngine} from "./interfaces/IAttestationAnchor.sol";

contract SettlementManager is ISettlementManager {
    IShipmentRegistry public immutable shipmentRegistry;
    IShipmentEscrow public immutable shipmentEscrow;
    IPenaltyEngine public immutable penaltyEngine;

    // shipmentId => proposed penalty
    mapping(bytes32 => uint256) public assessedPenalties;

    constructor(
        address shipmentRegistryAddress,
        address shipmentEscrowAddress,
        address penaltyEngineAddress
    ) {
        shipmentRegistry = IShipmentRegistry(shipmentRegistryAddress);
        shipmentEscrow = IShipmentEscrow(shipmentEscrowAddress);
        penaltyEngine = IPenaltyEngine(penaltyEngineAddress);
    }

    function recordExcursionPenalty(
        bytes32 shipmentId,
        IPenaltyEngine.ExcursionEvent calldata excursion,
        uint256 maxPenaltyCap
    ) external {
        IShipmentRegistry.Shipment memory s = shipmentRegistry.getShipment(shipmentId);
        uint256 penalty = penaltyEngine.calculatePenalty(s.policyId, excursion, maxPenaltyCap);
        assessedPenalties[shipmentId] = penalty;
    }

    function settleShipment(bytes32 shipmentId) external override {
        IShipmentRegistry.Shipment memory s = shipmentRegistry.getShipment(shipmentId);
        require(
            s.status == IShipmentRegistry.ShipmentStatus.Delivered ||
            msg.sender == s.receiver ||
            msg.sender == s.owner,
            "Not eligible for settlement"
        );

        uint256 penalty = assessedPenalties[shipmentId];

        (uint256 carrierPayout, uint256 shipperRefund) = shipmentEscrow.executeSettlementPayout(
            shipmentId,
            s.carrier,
            s.owner,
            penalty
        );

        shipmentRegistry.updateStatus(shipmentId, IShipmentRegistry.ShipmentStatus.Settled);

        emit SettlementExecuted(shipmentId, penalty, carrierPayout, shipperRefund);
    }
}
