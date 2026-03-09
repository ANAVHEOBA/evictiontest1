// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultBase} from "./EvictionVaultBase.sol";

contract EvictionVaultDeposit is EvictionVaultBase {
    constructor(address[] memory _owners, uint256 _threshold) payable EvictionVaultBase(_owners, _threshold) {}

    receive() external payable {
        _creditDeposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        _creditDeposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "zero amount");
        require(balances[msg.sender] >= amount, "insufficient balance");
        balances[msg.sender] -= amount;
        totalVaultValue -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    function _creditDeposit(address account, uint256 amount) internal {
        require(amount > 0, "zero amount");
        balances[account] += amount;
        totalVaultValue += amount;
        emit Deposit(account, amount);
    }
}
