// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IShipmentRegistry {
    enum ShipmentStatus {
        Created,
        EscrowFunded,
        InTransit,
        Delivered,
        Settled,
        Cancelled,
        Disputed
    }

    struct Shipment {
        bytes32 shipmentId;
        address owner;             // Shipper / Manufacturer
        address carrier;           // Logistics Provider
        address receiver;          // Consignee
        address assignedDevice;    // IoT tracker device address
        bytes32 policyId;          // Temperature Policy identifier
        string productCategory;    // e.g. "COVID-19 mRNA Vaccine"
        string originLocation;
        string destinationLocation;
        ShipmentStatus status;
        uint64 createdAt;
        uint64 departedAt;
        uint64 deliveredAt;
    }

    event ShipmentCreated(bytes32 indexed shipmentId, address indexed owner, address indexed carrier, bytes32 policyId);
    event ShipmentStatusChanged(bytes32 indexed shipmentId, ShipmentStatus oldStatus, ShipmentStatus newStatus);
    event DeviceAssigned(bytes32 indexed shipmentId, address indexed device);

    error ShipmentAlreadyExists(bytes32 shipmentId);
    error ShipmentNotFound(bytes32 shipmentId);
    error InvalidStatusTransition(ShipmentStatus current, ShipmentStatus requested);
    error UnauthorizedCaller(address caller);

    function createShipment(
        bytes32 shipmentId,
        address carrier,
        address receiver,
        bytes32 policyId,
        string calldata productCategory,
        string calldata origin,
        string calldata destination
    ) external;

    function assignDevice(bytes32 shipmentId, address device) external;
    function updateStatus(bytes32 shipmentId, ShipmentStatus newStatus) external;
    function getShipment(bytes32 shipmentId) external view returns (Shipment memory);
}
