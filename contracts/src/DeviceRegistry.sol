// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDeviceRegistry} from "./interfaces/IDeviceRegistry.sol";

contract DeviceRegistry is IDeviceRegistry {
    address public admin;

    mapping(address => Device) private _devices;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(address initialAdmin) {
        admin = initialAdmin == address(0) ? msg.sender : initialAdmin;
    }

    function registerDevice(string calldata serialNumber, string calldata sensorModel) external override {
        if (_devices[msg.sender].registeredAt != 0) revert DeviceAlreadyRegistered(msg.sender);

        _devices[msg.sender] = Device({
            deviceAddress: msg.sender,
            serialNumber: serialNumber,
            sensorModel: sensorModel,
            currentShipmentId: bytes32(0),
            status: DeviceStatus.Active,
            registeredAt: uint64(block.timestamp),
            lastCalibratedAt: uint64(block.timestamp)
        });

        emit DeviceRegistered(msg.sender, serialNumber, sensorModel);
    }

    function setDeviceStatus(address deviceAddress, DeviceStatus status) external override onlyAdmin {
        Device storage d = _devices[deviceAddress];
        if (d.registeredAt == 0) revert DeviceNotFound(deviceAddress);

        DeviceStatus old = d.status;
        d.status = status;
        emit DeviceStatusUpdated(deviceAddress, old, status);
    }

    function bindDeviceToShipment(address deviceAddress, bytes32 shipmentId) external override onlyAdmin {
        Device storage d = _devices[deviceAddress];
        if (d.registeredAt == 0) revert DeviceNotFound(deviceAddress);
        if (d.status != DeviceStatus.Active) revert DeviceNotActive(deviceAddress, d.status);
        if (d.currentShipmentId != bytes32(0) && d.currentShipmentId != shipmentId) {
            revert DeviceAlreadyBound(deviceAddress, d.currentShipmentId);
        }

        d.currentShipmentId = shipmentId;
        emit DeviceBoundToShipment(deviceAddress, shipmentId);
    }

    function unbindDeviceFromShipment(address deviceAddress) external override onlyAdmin {
        Device storage d = _devices[deviceAddress];
        if (d.registeredAt == 0) revert DeviceNotFound(deviceAddress);

        bytes32 prev = d.currentShipmentId;
        d.currentShipmentId = bytes32(0);
        emit DeviceUnboundFromShipment(deviceAddress, prev);
    }

    function getDevice(address deviceAddress) external view override returns (Device memory) {
        Device memory d = _devices[deviceAddress];
        if (d.registeredAt == 0) revert DeviceNotFound(deviceAddress);
        return d;
    }

    function isDeviceAuthorized(address deviceAddress, bytes32 shipmentId) external view override returns (bool) {
        Device memory d = _devices[deviceAddress];
        return d.status == DeviceStatus.Active && d.currentShipmentId == shipmentId;
    }
}
