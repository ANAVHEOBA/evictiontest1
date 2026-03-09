// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EvictionVault} from "../src/EvictionVault.sol";

contract PayableReceiver {
    uint256 public totalReceived;
    uint256 public lastArg;

    function store(uint256 ethAmount) external payable {
        lastArg = ethAmount;
        totalReceived += msg.value;
    }
}

contract EvictionVaultTest is Test {
    uint256 internal owner1Pk = 0xA11CE;
    uint256 internal owner2Pk = 0xB0B;
    uint256 internal owner3Pk = 0xCAFE;

    address internal owner1;
    address internal owner2;
    address internal owner3;

    address internal user = makeAddr("user");
    address internal other = makeAddr("other");

    EvictionVault internal vault;
    PayableReceiver internal receiver;

    function setUp() public {
        owner1 = vm.addr(owner1Pk);
        owner2 = vm.addr(owner2Pk);
        owner3 = vm.addr(owner3Pk);

        vm.deal(owner1, 10 ether);
        vm.deal(owner2, 10 ether);
        vm.deal(owner3, 10 ether);
        vm.deal(user, 20 ether);

        address[] memory council = new address[](3);
        council[0] = owner1;
        council[1] = owner2;
        council[2] = owner3;

        vault = new EvictionVault{value: 5 ether}(council, 2);
        receiver = new PayableReceiver();
    }

    function testConstructorInitialState() public view {
        assertEq(vault.approvalsRequired(), 2);
        assertEq(vault.actionNonce(), 0);
        assertEq(vault.trackedVaultBalance(), 5 ether);
        assertEq(address(vault).balance, 5 ether);
        assertTrue(vault.isCouncilMember(owner1));
        assertTrue(vault.isCouncilMember(owner2));
        assertTrue(vault.isCouncilMember(owner3));
    }

    function testConstructorRevertNoOwners() public {
        address[] memory council = new address[](0);
        vm.expectRevert("no owners");
        new EvictionVault(council, 1);
    }

    function testConstructorRevertInvalidThreshold() public {
        address[] memory council = new address[](2);
        council[0] = owner1;
        council[1] = owner2;

        vm.expectRevert("invalid threshold");
        new EvictionVault(council, 0);

        vm.expectRevert("invalid threshold");
        new EvictionVault(council, 3);
    }

    function testConstructorRevertZeroOwner() public {
        address[] memory council = new address[](2);
        council[0] = owner1;
        council[1] = address(0);

        vm.expectRevert("invalid owner");
        new EvictionVault(council, 1);
    }

    function testConstructorRevertDuplicateOwner() public {
        address[] memory council = new address[](2);
        council[0] = owner1;
        council[1] = owner1;

        vm.expectRevert("duplicate owner");
        new EvictionVault(council, 1);
    }

    function testDepositAndReceiveUpdateBalances() public {
        vm.prank(user);
        vault.deposit{value: 2 ether}();

        assertEq(vault.accountLedger(user), 2 ether);
        assertEq(vault.trackedVaultBalance(), 7 ether);

        vm.prank(user);
        (bool ok,) = address(vault).call{value: 1 ether}("");
        assertTrue(ok);

        assertEq(vault.accountLedger(user), 3 ether);
        assertEq(vault.trackedVaultBalance(), 8 ether);
        assertEq(address(vault).balance, 8 ether);
    }

    function testWithdrawSuccess() public {
        vm.prank(user);
        vault.deposit{value: 2 ether}();

        uint256 userBefore = user.balance;
        vm.prank(user);
        vault.withdraw(1.5 ether);

        assertEq(vault.accountLedger(user), 0.5 ether);
        assertEq(vault.trackedVaultBalance(), 5.5 ether);
        assertEq(user.balance, userBefore + 1.5 ether);
    }

    function testWithdrawRevertInsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert("insufficient balance");
        vault.withdraw(1);
    }

    function testWithdrawRevertWhenPaused() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}();

        vm.prank(owner1);
        vault.pause();

        vm.prank(user);
        vm.expectRevert("paused");
        vault.withdraw(0.5 ether);
    }

    function testPauseUnpauseOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("only owner");
        vault.pause();

        vm.prank(owner1);
        vault.pause();
        assertTrue(vault.isHalted());

        vm.prank(user);
        vm.expectRevert("only owner");
        vault.unpause();

        vm.prank(owner2);
        vault.unpause();
        assertFalse(vault.isHalted());
    }

    function testEmergencyWithdrawAllSuccess() public {
        vm.prank(user);
        vault.deposit{value: 2 ether}();

        uint256 ownerBefore = owner1.balance;
        uint256 amount = address(vault).balance;

        vm.prank(owner1);
        vault.emergencyWithdrawAll();

        assertEq(owner1.balance, ownerBefore + amount);
        assertEq(address(vault).balance, 0);
        assertEq(vault.trackedVaultBalance(), 0);
    }

    function testEmergencyWithdrawAllRevertOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("only owner");
        vault.emergencyWithdrawAll();
    }

    function testEmergencyWithdrawAllRevertWhenEmpty() public {
        address[] memory council = new address[](2);
        council[0] = owner1;
        council[1] = owner2;

        EvictionVault emptyVault = new EvictionVault(council, 2);

        vm.prank(owner1);
        vm.expectRevert("empty vault");
        emptyVault.emergencyWithdrawAll();
    }

    function testSetMerkleRootOnlyOwner() public {
        bytes32 root = keccak256("root");

        vm.prank(user);
        vm.expectRevert("only owner");
        vault.setMerkleRoot(root);

        vm.prank(owner1);
        vault.setMerkleRoot(root);

        assertEq(vault.payoutRoot(), root);
    }

    function testClaimSuccess() public {
        uint256 amount = 1 ether;
        bytes32 userLeaf = keccak256(abi.encodePacked(user, amount));
        bytes32 otherLeaf = keccak256(abi.encodePacked(other, amount));
        bytes32 root = _hashPair(userLeaf, otherLeaf);

        vm.prank(owner1);
        vault.setMerkleRoot(root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = otherLeaf;

        uint256 userBefore = user.balance;
        vm.prank(user);
        vault.claim(proof, amount);

        assertTrue(vault.hasClaimedPayout(user));
        assertEq(user.balance, userBefore + amount);
        assertEq(vault.trackedVaultBalance(), 4 ether);
    }

    function testClaimRevertInvalidProof() public {
        uint256 amount = 1 ether;
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256("wrong");

        vm.prank(owner1);
        vault.setMerkleRoot(keccak256("different root"));

        vm.prank(user);
        vm.expectRevert("invalid proof");
        vault.claim(proof, amount);
    }

    function testClaimRevertAlreadyClaimed() public {
        uint256 amount = 1 ether;
        bytes32 userLeaf = keccak256(abi.encodePacked(user, amount));
        bytes32 otherLeaf = keccak256(abi.encodePacked(other, amount));
        bytes32 root = _hashPair(userLeaf, otherLeaf);

        vm.prank(owner1);
        vault.setMerkleRoot(root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = otherLeaf;

        vm.prank(user);
        vault.claim(proof, amount);

        vm.prank(user);
        vm.expectRevert("already claimed");
        vault.claim(proof, amount);
    }

    function testClaimRevertWhenPaused() public {
        vm.prank(owner1);
        vault.pause();

        bytes32[] memory proof = new bytes32[](0);
        vm.prank(user);
        vm.expectRevert("paused");
        vault.claim(proof, 1 ether);
    }

    function testSubmitTransactionAndStoreData() public {
        bytes memory callData = abi.encodeWithSelector(PayableReceiver.store.selector, 42);

        vm.prank(owner1);
        vault.submitTransaction(address(receiver), 1 ether, callData);

        assertEq(vault.actionNonce(), 1);
        assertTrue(vault.hasApproved(0, owner1));

        (
            address target,
            uint256 ethAmount,
            bytes memory storedData,
            bool wasExecuted,
            uint256 approvalCount,
            uint256 createdAt,
            uint256 executableAt
        ) = vault.queuedActions(0);

        assertEq(target, address(receiver));
        assertEq(ethAmount, 1 ether);
        assertEq(storedData, callData);
        assertFalse(wasExecuted);
        assertEq(approvalCount, 1);
        assertEq(createdAt, block.timestamp);
        assertEq(executableAt, 0);
    }

    function testSubmitTransactionRevertOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("only owner");
        vault.submitTransaction(address(receiver), 1 ether, "");
    }

    function testSubmitTransactionRevertInvalidTarget() public {
        vm.prank(owner1);
        vm.expectRevert("invalid target");
        vault.submitTransaction(address(0), 1 ether, "");
    }

    function testSubmitAndConfirmSetExecutionTimeAtThreshold() public {
        vm.prank(owner1);
        vault.submitTransaction(address(receiver), 0.1 ether, "");

        uint256 expectedExecutionTime = block.timestamp + vault.EXECUTION_DELAY();

        vm.prank(owner2);
        vault.confirmTransaction(0);

        (, , , , uint256 approvalCount, , uint256 executableAt) = vault.queuedActions(0);
        assertEq(approvalCount, 2);
        assertEq(executableAt, expectedExecutionTime);
        assertTrue(vault.hasApproved(0, owner2));
    }

    function testConfirmTransactionRevertAlreadyConfirmed() public {
        vm.prank(owner1);
        vault.submitTransaction(address(receiver), 0, "");

        vm.prank(owner1);
        vm.expectRevert("already confirmed");
        vault.confirmTransaction(0);
    }

    function testConfirmTransactionRevertTxDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert("tx does not exist");
        vault.confirmTransaction(999);
    }

    function testExecuteTransactionRevertInsufficientConfirmations() public {
        vm.prank(owner1);
        vault.submitTransaction(address(receiver), 1 ether, "");

        vm.expectRevert("insufficient confirmations");
        vault.executeTransaction(0);
    }

    function testExecuteTransactionRevertTxDoesNotExist() public {
        vm.expectRevert("tx does not exist");
        vault.executeTransaction(404);
    }

    function testExecuteTransactionRevertTimelockNotReached() public {
        vm.prank(owner1);
        vault.submitTransaction(address(receiver), 1 ether, "");

        vm.prank(owner2);
        vault.confirmTransaction(0);

        vm.expectRevert("timelock not reached");
        vault.executeTransaction(0);
    }

    function testExecuteTransactionSuccess() public {
        bytes memory callData = abi.encodeWithSelector(PayableReceiver.store.selector, 99);
        uint256 vaultBefore = vault.trackedVaultBalance();

        vm.prank(owner1);
        vault.submitTransaction(address(receiver), 1 ether, callData);

        vm.prank(owner2);
        vault.confirmTransaction(0);

        vm.warp(block.timestamp + vault.EXECUTION_DELAY());
        vault.executeTransaction(0);

        (, , , bool wasExecuted, , , ) = vault.queuedActions(0);
        assertTrue(wasExecuted);
        assertEq(receiver.totalReceived(), 1 ether);
        assertEq(receiver.lastArg(), 99);
        assertEq(vault.trackedVaultBalance(), vaultBefore - 1 ether);
    }

    function testExecuteTransactionRevertAlreadyExecuted() public {
        vm.prank(owner1);
        vault.submitTransaction(user, 0, "");

        vm.prank(owner2);
        vault.confirmTransaction(0);

        vm.warp(block.timestamp + vault.EXECUTION_DELAY());
        vault.executeTransaction(0);

        vm.expectRevert("already executed");
        vault.executeTransaction(0);
    }

    function testConfirmTransactionRevertAlreadyExecuted() public {
        vm.prank(owner1);
        vault.submitTransaction(user, 0, "");

        vm.prank(owner2);
        vault.confirmTransaction(0);

        vm.warp(block.timestamp + vault.EXECUTION_DELAY());
        vault.executeTransaction(0);

        vm.prank(owner3);
        vm.expectRevert("already executed");
        vault.confirmTransaction(0);
    }

    function testVerifySignatureValidAndInvalidCases() public view {
        bytes32 digest = keccak256("eviction-vault");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Pk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertTrue(vault.verifySignature(owner1, digest, sig));
        assertFalse(vault.verifySignature(owner2, digest, sig));

        bytes memory shortSig = hex"1234";
        assertFalse(vault.verifySignature(owner1, digest, shortSig));

        bytes memory tamperedSig = abi.encodePacked(bytes32(uint256(r) + 1), s, v);
        assertFalse(vault.verifySignature(owner1, digest, tamperedSig));
    }

    function testPauseRevertAlreadyPaused() public {
        vm.prank(owner1);
        vault.pause();

        vm.prank(owner2);
        vm.expectRevert("already paused");
        vault.pause();
    }

    function testUnpauseRevertNotPaused() public {
        vm.prank(owner1);
        vm.expectRevert("not paused");
        vault.unpause();
    }

    function testThresholdOneSetsTimelockOnSubmit() public {
        address[] memory council = new address[](1);
        council[0] = owner1;
        EvictionVault single = new EvictionVault{value: 1 ether}(council, 1);

        vm.prank(owner1);
        single.submitTransaction(user, 0, "");

        (, , , , uint256 approvalCount, uint256 createdAt, uint256 executableAt) = single.queuedActions(0);
        assertEq(approvalCount, 1);
        assertEq(executableAt, createdAt + single.EXECUTION_DELAY());
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}
