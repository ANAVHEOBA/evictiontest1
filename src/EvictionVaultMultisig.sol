// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultMerkle} from "./EvictionVaultMerkle.sol";

contract EvictionVaultMultisig is EvictionVaultMerkle {
    constructor(address[] memory _owners, uint256 _threshold) payable EvictionVaultMerkle(_owners, _threshold) {}

    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner whenNotPaused {
        require(to != address(0), "invalid target");

        uint256 id = txCount++;
        uint256 executionTime = threshold == 1 ? block.timestamp + TIMELOCK_DURATION : 0;

        transactions[id] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 1,
            submissionTime: block.timestamp,
            executionTime: executionTime
        });

        confirmed[id][msg.sender] = true;
        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external onlyOwner whenNotPaused {
        require(txId < txCount, "tx does not exist");

        Transaction storage txn = transactions[txId];
        require(!txn.executed, "already executed");
        require(!confirmed[txId][msg.sender], "already confirmed");

        confirmed[txId][msg.sender] = true;
        txn.confirmations++;

        if (txn.confirmations == threshold) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }

        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external whenNotPaused nonReentrant {
        require(txId < txCount, "tx does not exist");

        Transaction storage txn = transactions[txId];
        require(txn.confirmations >= threshold, "insufficient confirmations");
        require(!txn.executed, "already executed");
        require(block.timestamp >= txn.executionTime, "timelock not reached");
        require(totalVaultValue >= txn.value, "insufficient vault value");

        txn.executed = true;
        totalVaultValue -= txn.value;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "execution failed");

        emit Execution(txId);
    }
}
