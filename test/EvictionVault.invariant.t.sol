// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {EvictionVault} from "../src/EvictionVault.sol";

contract InvariantSink {
    uint256 public totalReceived;

    receive() external payable {
        totalReceived += msg.value;
    }
}

contract EvictionVaultHandler is Test {
    EvictionVault internal vault;
    InvariantSink internal sink;

    address internal ownerA;
    address internal ownerB;
    address internal ownerC;
    address internal userA;
    address internal userB;

    constructor(
        EvictionVault _vault,
        InvariantSink _sink,
        address _ownerA,
        address _ownerB,
        address _ownerC,
        address _userA,
        address _userB
    ) {
        vault = _vault;
        sink = _sink;
        ownerA = _ownerA;
        ownerB = _ownerB;
        ownerC = _ownerC;
        userA = _userA;
        userB = _userB;
    }

    function deposit(uint8 who, uint96 rawAmount) external {
        address actor = _pickUser(who);
        uint256 amount = bound(uint256(rawAmount), 1, 1 ether);

        vm.deal(actor, actor.balance + amount);
        vm.prank(actor);
        try vault.deposit{value: amount}() {}
        catch {}
    }

    function withdraw(uint8 who, uint96 rawAmount) external {
        address actor = _pickUser(who);
        uint256 bal = vault.accountLedger(actor);
        if (bal == 0) return;

        uint256 amount = bound(uint256(rawAmount), 1, bal);
        vm.prank(actor);
        try vault.withdraw(amount) {}
        catch {}
    }

    function pauseVault(uint8 whichOwner) external {
        vm.prank(_pickOwner(whichOwner));
        try vault.pause() {}
        catch {}
    }

    function unpauseVault(uint8 whichOwner) external {
        vm.prank(_pickOwner(whichOwner));
        try vault.unpause() {}
        catch {}
    }

    function submitAction(uint8 whichOwner, uint96 rawAmount) external {
        address owner = _pickOwner(whichOwner);
        uint256 cap = vault.trackedVaultBalance();
        uint256 amount = cap == 0 ? 0 : bound(uint256(rawAmount), 0, cap > 1 ether ? 1 ether : cap);

        vm.prank(owner);
        try vault.submitTransaction(address(sink), amount, "") {}
        catch {}
    }

    function confirmAction(uint8 whichOwner, uint256 rawTxId) external {
        uint256 nonce = vault.actionNonce();
        if (nonce == 0) return;

        uint256 txId = bound(rawTxId, 0, nonce - 1);
        vm.prank(_pickOwner(whichOwner));
        try vault.confirmTransaction(txId) {}
        catch {}
    }

    function executeAction(uint256 rawTxId) external {
        uint256 nonce = vault.actionNonce();
        if (nonce == 0) return;

        uint256 txId = bound(rawTxId, 0, nonce - 1);
        vm.warp(block.timestamp + vault.EXECUTION_DELAY() + 1);

        try vault.executeTransaction(txId) {}
        catch {}
    }

    function setRootForUserA(uint8 whichOwner, uint96 rawAmount) external {
        uint256 amount = bound(uint256(rawAmount), 1, 1 ether);

        bytes32 leafA = keccak256(abi.encodePacked(userA, amount));
        bytes32 leafB = keccak256(abi.encodePacked(userB, amount));
        bytes32 root = _hashPair(leafA, leafB);

        vm.prank(_pickOwner(whichOwner));
        try vault.setMerkleRoot(root) {}
        catch {}
    }

    function claimUserA(uint96 rawAmount) external {
        uint256 amount = bound(uint256(rawAmount), 1, 1 ether);

        bytes32 leafB = keccak256(abi.encodePacked(userB, amount));
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafB;

        vm.prank(userA);
        try vault.claim(proof, amount) {}
        catch {}
    }

    function _pickOwner(uint8 seed) internal view returns (address) {
        if (seed % 3 == 0) return ownerA;
        if (seed % 3 == 1) return ownerB;
        return ownerC;
    }

    function _pickUser(uint8 seed) internal view returns (address) {
        return seed % 2 == 0 ? userA : userB;
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}

contract EvictionVaultInvariantTest is StdInvariant, Test {
    EvictionVault internal vault;
    EvictionVaultHandler internal handler;
    InvariantSink internal sink;

    address internal ownerA;
    address internal ownerB;
    address internal ownerC;
    address internal userA;
    address internal userB;

    function setUp() public {
        ownerA = vm.addr(0xA11CE);
        ownerB = vm.addr(0xB0B);
        ownerC = vm.addr(0xCAFE);
        userA = makeAddr("inv_user_a");
        userB = makeAddr("inv_user_b");

        address[] memory council = new address[](3);
        council[0] = ownerA;
        council[1] = ownerB;
        council[2] = ownerC;

        vm.deal(address(this), 100 ether);
        vault = new EvictionVault{value: 5 ether}(council, 2);
        sink = new InvariantSink();

        handler = new EvictionVaultHandler(vault, sink, ownerA, ownerB, ownerC, userA, userB);
        targetContract(address(handler));
    }

    function invariant_TrackedBalanceMatchesActualBalance() public view {
        assertEq(vault.trackedVaultBalance(), address(vault).balance);
    }

    function invariant_CouncilAndThresholdStayStable() public view {
        address[] memory members = vault.getOwners();
        assertEq(members.length, 3);
        assertEq(vault.approvalsRequired(), 2);
        assertTrue(vault.isCouncilMember(ownerA));
        assertTrue(vault.isCouncilMember(ownerB));
        assertTrue(vault.isCouncilMember(ownerC));
    }
}
