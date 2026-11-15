// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAttestationAnchor} from "./interfaces/IAttestationAnchor.sol";

contract AttestationAnchor is IAttestationAnchor {
    address public authorizedOracle;

    // shipmentId => merkleRoot => BatchCommitment
    mapping(bytes32 => mapping(bytes32 => BatchCommitment)) private _batches;
    // shipmentId => merkleRoot => exists
    mapping(bytes32 => mapping(bytes32 => bool)) private _isKnownRoot;

    modifier onlyOracle() {
        if (msg.sender != authorizedOracle) revert UnauthorizedPublisher();
        _;
    }

    constructor(address initialOracle) {
        authorizedOracle = initialOracle == address(0) ? msg.sender : initialOracle;
    }

    function anchorBatch(
        bytes32 shipmentId,
        bytes32 merkleRoot,
        uint32 readingCount,
        uint64 startTimestamp,
        uint64 endTimestamp,
        string calldata ipfsReportCID
    ) external override onlyOracle {
        if (_isKnownRoot[shipmentId][merkleRoot]) revert DuplicateBatchRoot(merkleRoot);

        _batches[shipmentId][merkleRoot] = BatchCommitment({
            merkleRoot: merkleRoot,
            readingCount: readingCount,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            ipfsReportCID: ipfsReportCID
        });

        _isKnownRoot[shipmentId][merkleRoot] = true;

        emit BatchAnchored(shipmentId, merkleRoot, readingCount, block.timestamp);
    }

    function isKnownBatchRoot(bytes32 shipmentId, bytes32 merkleRoot) external view override returns (bool) {
        return _isKnownRoot[shipmentId][merkleRoot];
    }
}
