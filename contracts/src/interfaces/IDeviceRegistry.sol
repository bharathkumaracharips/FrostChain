// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDeviceRegistry {
    enum DeviceStatus { Inactive, Active, Suspended, Revoked }

    struct Device {
        address deviceAddress;      // Device cryptographic signing address
        string serialNumber;        // Physical serial number (e.g. ESP32-MAC)
        string sensorModel;         // e.g. "DS18B20" or "SHT31"
        bytes32 currentShipmentId;  // Currently assigned shipment
        DeviceStatus status;
        uint64 registeredAt;
        uint64 lastCalibratedAt;
    }

    event DeviceRegistered(address indexed deviceAddress, string serialNumber, string sensorModel);
    event DeviceStatusUpdated(address indexed deviceAddress, DeviceStatus oldStatus, DeviceStatus newStatus);
    event DeviceBoundToShipment(address indexed deviceAddress, bytes32 indexed shipmentId);
    event DeviceUnboundFromShipment(address indexed deviceAddress, bytes32 indexed shipmentId);

    error DeviceAlreadyRegistered(address deviceAddress);
    error DeviceNotFound(address deviceAddress);
    error DeviceNotActive(address deviceAddress, DeviceStatus status);
    error DeviceAlreadyBound(address deviceAddress, bytes32 currentShipment);

    function registerDevice(string calldata serialNumber, string calldata sensorModel) external;
    function setDeviceStatus(address deviceAddress, DeviceStatus status) external;
    function bindDeviceToShipment(address deviceAddress, bytes32 shipmentId) external;
    function unbindDeviceFromShipment(address deviceAddress) external;
    function getDevice(address deviceAddress) external view returns (Device memory);
    function isDeviceAuthorized(address deviceAddress, bytes32 shipmentId) external view returns (bool);
}

interface ITemperaturePolicyManager {
    struct TemperaturePolicy {
        bytes32 policyId;
        string policyName;
        int16 minTemp;                         // In centi-degrees Celsius (e.g. 200 = 2.00°C)
        int16 maxTemp;                         // In centi-degrees Celsius (e.g. 800 = 8.00°C)
        uint32 maxContinuousExcursionSeconds;  // Grace period before penalties start
        uint32 maxCumulativeExcursionSeconds;  // Maximum total excursion allowed
        int16 criticalSpoilageMinTemp;         // Instant total loss temperature (freezing)
        int16 criticalSpoilageMaxTemp;         // Instant total loss temperature (heat)
        uint256 penaltyPerExcursionSecond;     // Wei or token base per second
    }

    event PolicyCreated(bytes32 indexed policyId, string policyName, int16 minTemp, int16 maxTemp);

    error PolicyAlreadyExists(bytes32 policyId);
    error PolicyNotFound(bytes32 policyId);
    error InvalidPolicyParameters();

    function createPolicy(
        bytes32 policyId,
        string calldata policyName,
        int16 minTemp,
        int16 maxTemp,
        uint32 maxContinuousExcursionSeconds,
        uint32 maxCumulativeExcursionSeconds,
        int16 criticalMin,
        int16 criticalMax,
        uint256 penaltyPerSecond
    ) external;

    function getPolicy(bytes32 policyId) external view returns (TemperaturePolicy memory);
}
