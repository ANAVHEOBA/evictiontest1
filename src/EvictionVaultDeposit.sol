// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EvictionVaultBase.sol";

contract EvictionVaultDeposit is EvictionVaultBase {
    constructor(address[] memory initialCouncil, uint256 minApprovals) payable EvictionVaultBase(initialCouncil, minApprovals) {}

    receive() external payable {
        _creditDeposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        _creditDeposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "zero amount");
        require(accountLedger[msg.sender] >= amount, "insufficient balance");
        accountLedger[msg.sender] -= amount;
        trackedVaultBalance -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    function _creditDeposit(address account, uint256 amount) internal {
        require(amount > 0, "zero amount");
        accountLedger[account] += amount;
        trackedVaultBalance += amount;
        emit Deposit(account, amount);
    }
}
