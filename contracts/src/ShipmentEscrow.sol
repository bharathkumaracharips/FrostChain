// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IShipmentEscrow} from "./interfaces/IAttestationAnchor.sol";

contract ShipmentEscrow is IShipmentEscrow {
    address public settlementManager;

    mapping(bytes32 => EscrowDeposit) private _escrows;

    modifier onlySettlementManager() {
        require(msg.sender == settlementManager, "Only settlement manager");
        _;
    }

    constructor(address initialSettlementManager) {
        settlementManager = initialSettlementManager == address(0) ? msg.sender : initialSettlementManager;
    }

    function setSettlementManager(address manager) external {
        require(settlementManager == address(0) || msg.sender == settlementManager, "Unauthorized");
        settlementManager = manager;
    }

    /**
     * @notice Funds escrow for a shipment: msg.value = serviceFee + penaltyReserve
     */
    function fundEscrow(bytes32 shipmentId, uint256 penaltyReserve) external payable override {
        if (_escrows[shipmentId].funded) revert EscrowAlreadyFunded(shipmentId);
        if (msg.value <= penaltyReserve) revert InsufficientFunds();

        uint256 serviceFee = msg.value - penaltyReserve;

        _escrows[shipmentId] = EscrowDeposit({
            serviceFee: serviceFee,
            penaltyReserve: penaltyReserve,
            carrierCollateral: 0,
            funded: true,
            settled: false
        });

        emit EscrowFunded(shipmentId, serviceFee, penaltyReserve);
    }

    /**
     * @notice Settles payment and refunds penalty to shipper if excursion occurred
     */
    function executeSettlementPayout(
        bytes32 shipmentId,
        address carrier,
        address shipper,
        uint256 penaltyAmount
    ) external override onlySettlementManager returns (uint256 carrierPayout, uint256 shipperRefund) {
        EscrowDeposit storage deposit = _escrows[shipmentId];
        if (!deposit.funded) revert EscrowNotFunded(shipmentId);
        if (deposit.settled) revert EscrowAlreadySettled(shipmentId);

        deposit.settled = true;

        uint256 maxPenalty = deposit.penaltyReserve;
        uint256 finalPenalty = penaltyAmount > maxPenalty ? maxPenalty : penaltyAmount;

        // Carrier receives serviceFee + any unpenalized portion of penalty reserve
        carrierPayout = deposit.serviceFee + (deposit.penaltyReserve - finalPenalty);
        // Shipper receives refund for penalties incurred
        shipperRefund = finalPenalty;

        if (carrierPayout > 0) {
            (bool s1, ) = carrier.call{value: carrierPayout}("");
            require(s1, "Carrier transfer failed");
        }
        if (shipperRefund > 0) {
            (bool s2, ) = shipper.call{value: shipperRefund}("");
            require(s2, "Shipper transfer failed");
        }

        emit EscrowSettled(shipmentId, carrierPayout, shipperRefund);
    }

    function getEscrow(bytes32 shipmentId) external view returns (EscrowDeposit memory) {
        return _escrows[shipmentId];
    }
}
