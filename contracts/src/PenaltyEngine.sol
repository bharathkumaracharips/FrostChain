// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPenaltyEngine} from "./interfaces/IAttestationAnchor.sol";
import {ITemperaturePolicyManager} from "./interfaces/IDeviceRegistry.sol";

contract PenaltyEngine is IPenaltyEngine {
    ITemperaturePolicyManager public immutable policyManager;

    constructor(address policyManagerAddress) {
        require(policyManagerAddress != address(0), "Zero address");
        policyManager = ITemperaturePolicyManager(policyManagerAddress);
    }

    function calculatePenalty(
        bytes32 policyId,
        ExcursionEvent calldata excursion,
        uint256 maxPenaltyCap
    ) external view override returns (uint256 penaltyAmount) {
        ITemperaturePolicyManager.TemperaturePolicy memory policy = policyManager.getPolicy(policyId);

        // 1. Check critical spoilage threshold (Total loss of cargo)
        if (excursion.criticalSpoilage ||
            excursion.minRecordedTemp <= policy.criticalSpoilageMinTemp ||
            excursion.maxRecordedTemp >= policy.criticalSpoilageMaxTemp) {
            return maxPenaltyCap; // 100% penalty
        }

        // 2. Check if excursion duration exceeded allowable continuous grace period
        if (excursion.durationSeconds <= policy.maxContinuousExcursionSeconds) {
            return 0; // Within grace period
        }

        uint256 excessSeconds = excursion.durationSeconds - policy.maxContinuousExcursionSeconds;
        uint256 basePenalty = excessSeconds * policy.penaltyPerExcursionSecond;

        // 3. Severity multiplier based on degrees of breach
        int16 breachDegrees = 0;
        if (excursion.maxRecordedTemp > policy.maxTemp) {
            breachDegrees = excursion.maxRecordedTemp - policy.maxTemp;
        } else if (excursion.minRecordedTemp < policy.minTemp) {
            breachDegrees = policy.minTemp - excursion.minRecordedTemp;
        }

        // Scale by (100 + breachDegrees) / 100
        uint256 multiplier = 100 + uint256(uint16(breachDegrees));
        penaltyAmount = (basePenalty * multiplier) / 100;

        if (penaltyAmount > maxPenaltyCap) {
            penaltyAmount = maxPenaltyCap;
        }
    }
}
