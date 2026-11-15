// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IChainOfCustody} from "./interfaces/IAttestationAnchor.sol";
import {IShipmentRegistry} from "./interfaces/IShipmentRegistry.sol";

contract ChainOfCustody is IChainOfCustody {
    IShipmentRegistry public immutable shipmentRegistry;

    // shipmentId => CustodyEvent[]
    mapping(bytes32 => CustodyEvent[]) private _custodyHistory;

    constructor(address shipmentRegistryAddress) {
        require(shipmentRegistryAddress != address(0), "Zero address");
        shipmentRegistry = IShipmentRegistry(shipmentRegistryAddress);
    }

    function transferCustody(
        bytes32 shipmentId,
        address to,
        CustodyRole role,
        string calldata location
    ) external override {
        IShipmentRegistry.Shipment memory s = shipmentRegistry.getShipment(shipmentId);
        require(
            msg.sender == s.owner || msg.sender == s.carrier || msg.sender == s.receiver,
            "Unauthorized custodian"
        );
        require(to != address(0), "Zero to address");

        _custodyHistory[shipmentId].push(CustodyEvent({
            fromCustodian: msg.sender,
            toCustodian: to,
            role: role,
            location: location,
            timestamp: uint64(block.timestamp)
        }));

        emit CustodyTransferred(shipmentId, msg.sender, to, location);
    }

    function getCustodyHistory(bytes32 shipmentId) external view returns (CustodyEvent[] memory) {
        return _custodyHistory[shipmentId];
    }
}
