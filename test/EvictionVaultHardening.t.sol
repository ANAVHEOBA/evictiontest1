// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EvictionVault} from "../src/EvictionVault.sol";

contract EvictionVaultHardeningTest is Test {
    EvictionVault vault;
    address owner1;
    address owner2;
    address owner3;
    address user1;
    address user2;

    function setUp() public {
        owner1 = address(0x1111);
        owner2 = address(0x2222);
        owner3 = address(0x3333);
        user1 = address(0x4444);
        user2 = address(0x5555);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        vault = new EvictionVault{value: 10 ether}(owners, 2);
    }

    // Test 1: Merkle root can only be set by owner (FIX: was public)
    function testMerkleRootOnlyOwner() public {
        bytes32 newRoot = keccak256(abi.encodePacked("new_root"));
        
        // Owner should succeed
        vm.prank(owner1);
        vault.setMerkleRoot(newRoot);
        assert(vault.merkleRoot() == newRoot);

        // Non-owner should fail
        vm.prank(user1);
        vm.expectRevert("only owner");
        vault.setMerkleRoot(keccak256(abi.encodePacked("another_root")));
    }

    // Test 2: Emergency withdraw only callable by owner (FIX: was public)
    function testEmergencyWithdrawOnlyOwner() public {
        uint256 initialBalance = address(vault).balance;
        
        // Owner should succeed
        vm.prank(owner1);
        vault.emergencyWithdrawAll();
        assert(address(vault).balance == 0);
        assert(owner1.balance == initialBalance);

        // Reset for next test
        vm.deal(address(vault), 5 ether);
        
        // Non-owner should fail
        vm.prank(user1);
        vm.expectRevert("only owner");
        vault.emergencyWithdrawAll();
    }

    // Test 3: Pause/Unpause require owner role (FIX: was single owner)
    function testPauseUnpauseOnlyOwner() public {
        // Owner can pause
        vm.prank(owner1);
        vault.pause();
        assert(vault.paused());

        // Owner can unpause
        vm.prank(owner1);
        vault.unpause();
        assert(!vault.paused());

        // Non-owner cannot pause
        vm.prank(user1);
        vm.expectRevert("only owner");
        vault.pause();
    }

    // Test 4: receive() uses msg.sender not tx.origin (FIX: was tx.origin)
    function testReceiveUsesMsgSender() public {
        // Send ETH via receive() - should credit msg.sender
        vm.prank(user1);
        (bool success, ) = address(vault).call{value: 1 ether}("");
        assert(success);
        assert(vault.balances(user1) == 1 ether);
    }

    // Test 5: withdraw uses call pattern, not transfer (FIX: was .transfer())
    function testWithdrawUsesCall() public {
        // Deposit then withdraw
        uint256 beforeBalance = user1.balance;
        vm.prank(user1);
        vault.deposit{value: 2 ether}();
        
        vm.prank(user1);
        vault.withdraw(2 ether);
        
        assert(vault.balances(user1) == 0);
        assert(user1.balance == beforeBalance);
    }

    // Test 6: claim uses call pattern, not transfer (FIX: was .transfer())
    function testClaimUsesCall() public {
        bytes32 leaf = keccak256(abi.encodePacked(user1, uint256(1 ether)));
        bytes32 root = keccak256(abi.encodePacked(leaf, leaf));
        
        vm.prank(owner1);
        vault.setMerkleRoot(root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf;

        uint256 beforeBalance = user1.balance;
        vm.prank(user1);
        vault.claim(proof, 1 ether);
        
        assert(vault.claimed(user1));
        assert(user1.balance == beforeBalance + 1 ether);
    }

    // Test 7: Timelock execution enforced
    function testTimelockEnforced() public {
        // Submit transaction
        vm.prank(owner1);
        vault.submitTransaction(user1, 1 ether, "");
        
        // Confirm by owner2 (now 2 confirmations = threshold)
        vm.prank(owner2);
        vault.confirmTransaction(0);
        
        // executionTime should be set
        (,,,,,, uint256 executionTime) = vault.transactions(0);
        assert(executionTime > block.timestamp);

        // Execution before timelock should fail
        vm.expectRevert("timelock not reached");
        vault.executeTransaction(0);

        // Wait for timelock
        vm.warp(executionTime + 1);
        
        // Now execution should succeed
        vault.executeTransaction(0);
    }

    // Test 8: Pause prevents withdrawal
    function testPausePreventsWithdrawal() public {
        vm.prank(user1);
        vault.deposit{value: 1 ether}();

        vm.prank(owner1);
        vault.pause();

        vm.prank(user1);
        vm.expectRevert("paused");
        vault.withdraw(1 ether);
    }

    // Test 9: Multi-sig threshold enforcement
    function testMultisigThreshold() public {
        vm.prank(owner1);
        vault.submitTransaction(user1, 1 ether, "");

        // With only 1 confirmation, execution should fail
        vm.expectRevert("insufficient confirmations");
        vault.executeTransaction(0);

        // Need 2nd confirmation
        vm.prank(owner2);
        vault.confirmTransaction(0);

        (,,,, uint256 confirmations,,) = vault.transactions(0);
        assert(confirmations == 2);
    }

    // Test 10: Verify signature works (improved from original)
    function testVerifySignature() public view {
        bytes32 messageHash = keccak256(abi.encodePacked("test message"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash);
        
        bytes memory signature = abi.encodePacked(r, s, v);
        address signer = vm.addr(1);
        
        bool valid = vault.verifySignature(signer, messageHash, signature);
        assert(valid);
    }

    receive() external payable {}
}
