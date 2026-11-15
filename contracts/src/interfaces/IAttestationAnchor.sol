// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAttestationAnchor {
    struct BatchCommitment {
        bytes32 merkleRoot;
        uint32 readingCount;
        uint64 startTimestamp;
        uint64 endTimestamp;
        string ipfsReportCID;
    }

    event BatchAnchored(
        bytes32 indexed shipmentId,
        bytes32 indexed merkleRoot,
        uint32 readingCount,
        uint256 timestamp
    );

    error UnauthorizedPublisher();
    error DuplicateBatchRoot(bytes32 root);

    function anchorBatch(
        bytes32 shipmentId,
        bytes32 merkleRoot,
        uint32 readingCount,
        uint64 startTimestamp,
        uint64 endTimestamp,
        string calldata ipfsReportCID
    ) external;

    function isKnownBatchRoot(bytes32 shipmentId, bytes32 merkleRoot) external view returns (bool);
}

interface IShipmentEscrow {
    struct EscrowDeposit {
        uint256 serviceFee;       // Payment to carrier upon successful delivery
        uint256 penaltyReserve;   // Collateral / reserved funds for temperature excursions
        uint256 carrierCollateral;// Carrier bond
        bool funded;
        bool settled;
    }

    event EscrowFunded(bytes32 indexed shipmentId, uint256 serviceFee, uint256 penaltyReserve);
    event EscrowSettled(bytes32 indexed shipmentId, uint256 carrierPayout, uint256 shipperRefund);

    error EscrowAlreadyFunded(bytes32 shipmentId);
    error EscrowNotFunded(bytes32 shipmentId);
    error EscrowAlreadySettled(bytes32 shipmentId);
    error InsufficientFunds();

    function fundEscrow(bytes32 shipmentId, uint256 penaltyReserve) external payable;
    function executeSettlementPayout(
        bytes32 shipmentId,
        address carrier,
        address shipper,
        uint256 penaltyAmount
    ) external returns (uint256 carrierPayout, uint256 shipperRefund);
}

interface IPenaltyEngine {
    struct ExcursionEvent {
        int16 minRecordedTemp;
        int16 maxRecordedTemp;
        uint32 durationSeconds;
        bool criticalSpoilage;
    }

    function calculatePenalty(
        bytes32 policyId,
        ExcursionEvent calldata excursion,
        uint256 maxPenaltyCap
    ) external view returns (uint256 penaltyAmount);
}

interface ISettlementManager {
    event SettlementExecuted(
        bytes32 indexed shipmentId,
        uint256 finalPenalty,
        uint256 carrierPayout,
        uint256 shipperRefund
    );

    function settleShipment(bytes32 shipmentId) external;
}

interface IChainOfCustody {
    enum CustodyRole { Shipper, Carrier, Warehouse, Receiver }

    struct CustodyEvent {
        address fromCustodian;
        address toCustodian;
        CustodyRole role;
        string location;
        uint64 timestamp;
    }

    event CustodyTransferred(bytes32 indexed shipmentId, address indexed from, address indexed to, string location);

    function transferCustody(bytes32 shipmentId, address to, CustodyRole role, string calldata location) external;
}
