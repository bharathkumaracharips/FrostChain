// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITemperaturePolicyManager} from "./interfaces/IDeviceRegistry.sol";

contract TemperaturePolicyManager is ITemperaturePolicyManager {
    mapping(bytes32 => TemperaturePolicy) private _policies;

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
    ) external override {
        if (_policies[policyId].policyId != bytes32(0)) revert PolicyAlreadyExists(policyId);
        if (minTemp >= maxTemp || criticalMin >= criticalMax) revert InvalidPolicyParameters();

        _policies[policyId] = TemperaturePolicy({
            policyId: policyId,
            policyName: policyName,
            minTemp: minTemp,
            maxTemp: maxTemp,
            maxContinuousExcursionSeconds: maxContinuousExcursionSeconds,
            maxCumulativeExcursionSeconds: maxCumulativeExcursionSeconds,
            criticalSpoilageMinTemp: criticalMin,
            criticalSpoilageMaxTemp: criticalMax,
            penaltyPerExcursionSecond: penaltyPerSecond
        });

        emit PolicyCreated(policyId, policyName, minTemp, maxTemp);
    }

    function getPolicy(bytes32 policyId) external view override returns (TemperaturePolicy memory) {
        TemperaturePolicy memory p = _policies[policyId];
        if (p.policyId == bytes32(0)) revert PolicyNotFound(policyId);
        return p;
    }
}
