// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultMerkle} from "./EvictionVaultMerkle.sol";

contract EvictionVaultMultisig is EvictionVaultMerkle {

    constructor(address[] memory _owners, uint256 _threshold) 
        payable 
        EvictionVaultMerkle(_owners, _threshold) 
    {}

    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner whenNotPaused {
        uint256 id = txCount++;
        transactions[id] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 1,
            submissionTime: block.timestamp,
            executionTime: 0
        });
        confirmed[id][msg.sender] = true;
        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external onlyOwner whenNotPaused {
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

    function executeTransaction(uint256 txId) external {
        Transaction storage txn = transactions[txId];
        require(txn.confirmations >= threshold, "insufficient confirmations");
        require(!txn.executed, "already executed");
        require(block.timestamp >= txn.executionTime, "timelock not reached");
        
        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "execution failed");
        
        emit Execution(txId);
    }
}
