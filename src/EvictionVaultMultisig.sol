// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultMerkle} from "./EvictionVaultMerkle.sol";

contract EvictionVaultMultisig is EvictionVaultMerkle {
    constructor(address[] memory initialCouncil, uint256 minApprovals) payable EvictionVaultMerkle(initialCouncil, minApprovals) {}

    function submitTransaction(address target, uint256 ethAmount, bytes calldata callData) external onlyOwner whenNotPaused {
        require(target != address(0), "invalid target");

        uint256 id = actionNonce++;
        uint256 executableAt = approvalsRequired == 1 ? block.timestamp + EXECUTION_DELAY : 0;

        queuedActions[id] = Transaction({
            target: target,
            ethAmount: ethAmount,
            callData: callData,
            wasExecuted: false,
            approvalCount: 1,
            createdAt: block.timestamp,
            executableAt: executableAt
        });

        hasApproved[id][msg.sender] = true;
        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external onlyOwner whenNotPaused {
        require(txId < actionNonce, "tx does not exist");

        Transaction storage txn = queuedActions[txId];
        require(!txn.wasExecuted, "already executed");
        require(!hasApproved[txId][msg.sender], "already confirmed");

        hasApproved[txId][msg.sender] = true;
        txn.approvalCount++;

        if (txn.approvalCount == approvalsRequired) {
            txn.executableAt = block.timestamp + EXECUTION_DELAY;
        }

        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external whenNotPaused nonReentrant {
        require(txId < actionNonce, "tx does not exist");

        Transaction storage txn = queuedActions[txId];
        require(txn.approvalCount >= approvalsRequired, "insufficient confirmations");
        require(!txn.wasExecuted, "already executed");
        require(block.timestamp >= txn.executableAt, "timelock not reached");
        require(trackedVaultBalance >= txn.ethAmount, "insufficient vault value");

        txn.wasExecuted = true;
        trackedVaultBalance -= txn.ethAmount;

        (bool success, ) = txn.target.call{value: txn.ethAmount}(txn.callData);
        require(success, "execution failed");

        emit Execution(txId);
    }
}
