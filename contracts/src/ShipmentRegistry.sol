// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IShipmentRegistry} from "./interfaces/IShipmentRegistry.sol";

contract ShipmentRegistry is IShipmentRegistry {
    address public protocolAdmin;

    mapping(bytes32 => Shipment) private _shipments;

    modifier onlyAdmin() {
        if (msg.sender != protocolAdmin) revert UnauthorizedCaller(msg.sender);
        _;
    }

    constructor(address initialAdmin) {
        protocolAdmin = initialAdmin == address(0) ? msg.sender : initialAdmin;
    }

    function createShipment(
        bytes32 shipmentId,
        address carrier,
        address receiver,
        bytes32 policyId,
        string calldata productCategory,
        string calldata origin,
        string calldata destination
    ) external override {
        if (_shipments[shipmentId].createdAt != 0) revert ShipmentAlreadyExists(shipmentId);
        require(carrier != address(0) && receiver != address(0), "Zero address");

        _shipments[shipmentId] = Shipment({
            shipmentId: shipmentId,
            owner: msg.sender,
            carrier: carrier,
            receiver: receiver,
            assignedDevice: address(0),
            policyId: policyId,
            productCategory: productCategory,
            originLocation: origin,
            destinationLocation: destination,
            status: ShipmentStatus.Created,
            createdAt: uint64(block.timestamp),
            departedAt: 0,
            deliveredAt: 0
        });

        emit ShipmentCreated(shipmentId, msg.sender, carrier, policyId);
    }

    function assignDevice(bytes32 shipmentId, address device) external override {
        Shipment storage s = _shipments[shipmentId];
        if (s.createdAt == 0) revert ShipmentNotFound(shipmentId);
        if (msg.sender != s.owner && msg.sender != protocolAdmin) revert UnauthorizedCaller(msg.sender);
        require(device != address(0), "Zero device");

        s.assignedDevice = device;
        emit DeviceAssigned(shipmentId, device);
    }

    function updateStatus(bytes32 shipmentId, ShipmentStatus newStatus) external override {
        Shipment storage s = _shipments[shipmentId];
        if (s.createdAt == 0) revert ShipmentNotFound(shipmentId);

        // Access control: only owner, carrier, receiver, or admin can update status according to lifecycle
        if (msg.sender != s.owner && msg.sender != s.carrier && msg.sender != s.receiver && msg.sender != protocolAdmin) {
            revert UnauthorizedCaller(msg.sender);
        }

        ShipmentStatus oldStatus = s.status;
        s.status = newStatus;

        if (newStatus == ShipmentStatus.InTransit && s.departedAt == 0) {
            s.departedAt = uint64(block.timestamp);
        } else if (newStatus == ShipmentStatus.Delivered && s.deliveredAt == 0) {
            s.deliveredAt = uint64(block.timestamp);
        }

        emit ShipmentStatusChanged(shipmentId, oldStatus, newStatus);
    }

    function getShipment(bytes32 shipmentId) external view override returns (Shipment memory) {
        Shipment memory s = _shipments[shipmentId];
        if (s.createdAt == 0) revert ShipmentNotFound(shipmentId);
        return s;
    }
}
