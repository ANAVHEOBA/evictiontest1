// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultMultisig} from "./EvictionVaultMultisig.sol";

// name of contract is EvictionVault and it import EvictionVaultMultisig
contract EvictionVault is EvictionVaultMultisig {
    // the constructor takes in 2 inputs 
    constructor(address[] memory initialCouncil, uint256 minApprovals) payable EvictionVaultMultisig(initialCouncil, minApprovals) {}

    function emergencyWithdrawAll() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "empty vault");

        trackedVaultBalance = 0;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "emergency withdraw failed");
    }

    function pause() external onlyOwner {
        require(!isHalted, "already paused");
        isHalted = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        require(isHalted, "not paused");
        isHalted = false;
        emit Unpaused(msg.sender);
    }
}
