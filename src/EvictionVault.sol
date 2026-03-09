// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultMultisig} from "./EvictionVaultMultisig.sol";

contract EvictionVault is EvictionVaultMultisig {
    constructor(address[] memory _owners, uint256 _threshold) payable EvictionVaultMultisig(_owners, _threshold) {}

    function emergencyWithdrawAll() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "empty vault");

        totalVaultValue = 0;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "emergency withdraw failed");
    }

    function pause() external onlyOwner {
        require(!paused, "already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        require(paused, "not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }
}
