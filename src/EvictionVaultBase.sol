// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EvictionVaultBase {
    struct Transaction {
        address target;
        uint256 ethAmount;
        bytes callData;
        bool wasExecuted;
        uint256 approvalCount;
        uint256 createdAt;
        uint256 executableAt;
    }

    address[] public council;
    mapping(address => bool) public isCouncilMember;

    uint256 public approvalsRequired;
    mapping(uint256 => mapping(address => bool)) public hasApproved;
    mapping(uint256 => Transaction) public queuedActions;

    uint256 public actionNonce;
    mapping(address => uint256) public accountLedger;

    bytes32 public payoutRoot;
    mapping(address => bool) public hasClaimedPayout;

    uint256 public constant EXECUTION_DELAY = 1 hours;
    uint256 public trackedVaultBalance;

    bool public isHalted;
    bool private reentryGuardLocked;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event Submission(uint256 indexed txId);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);
    event MerkleRootSet(bytes32 indexed newRoot);
    event Claim(address indexed claimant, uint256 amount);
    event Paused(address indexed owner);
    event Unpaused(address indexed owner);

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _onlyOwner() internal view {
        require(isCouncilMember[msg.sender], "only owner");
    }

    function _whenNotPaused() internal view {
        require(!isHalted, "paused");
    }

    function _nonReentrantBefore() internal {
        require(!reentryGuardLocked, "reentrant call");
        reentryGuardLocked = true;
    }

    function _nonReentrantAfter() internal {
        reentryGuardLocked = false;
    }

    constructor(address[] memory initialCouncil, uint256 minApprovals) payable {
        require(initialCouncil.length > 0, "no owners");
        require(minApprovals > 0 && minApprovals <= initialCouncil.length, "invalid threshold");

        approvalsRequired = minApprovals;

        for (uint i = 0; i < initialCouncil.length; i++) {
            address member = initialCouncil[i];
            require(member != address(0), "invalid owner");
            require(!isCouncilMember[member], "duplicate owner");
            isCouncilMember[member] = true;
            council.push(member);
        }
        trackedVaultBalance = msg.value;
    }

    function getOwners() external view returns (address[] memory) {
        return council;
    }
}
