// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultMultisig} from "./EvictionVaultMultisig.sol";

// the name of the file is EVictionVault and the file that being imported is EvictionVaultMultisig
contract EvictionVault is EvictionVaultMultisig {

    // the constructor in this case is like u putting a door in one part of the house(contract)
    // now the input for the constructor is the address list which is stored in memory and _owners is the name 
    // and the threshold value it data type is uint256
    constructor(address[] memory _owners, uint256 _threshold) 
        // to make an address payable(to be able to receive money)
        payable
        // the  input from the constructor
        EvictionVaultMultisig(_owners, _threshold) 
    {}
    // now this particular line, the name of the function being emergencyWithdrawAll(), it not taking any input and the visbility is external 
    // and the response should be onlyOwner
    function emergencyWithdrawAll() external onlyOwner {
        // now this line is basically saying that the address of the contract(like an account number) and the balance 
        // address(this).balance is like saying the account number of the contract and the balance of that contract must bve greater than 0
        // if not show a message empty vault 
        require(address(this).balance > 0, "empty vault");
        // the data type is the uint256 and the variable being used here is balance
        // the account number of this contract and the balance of that account
        uint256 balance = address(this).balance;
        // where the default totalVaultValue is set to 0
        totalVaultValue = 0;

        // i always cram this line
        // payable(msg.sender) which makes an address payable like an abilty to receive money 
        // call{value : balance}
        // ("")
        // (bool success, ) which means that the transfer was successful true or false(successful or unsuccessful)
        // so it like saying make the address payable like it can receive tokens and then call is next to check if it can actually receive tokens
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        // so this is basically saying if the operation was not successful show a message name "emergency withdraw failed"
        require(success, "emergency withdraw failed");
        
    }


    // the name of the function is pause and the visbilty is external and the response should be onlyOwner
    function pause() external onlyOwner {
        // so this is saying that the default value of paused is true
        paused = true;

        // and it should an event named paused with the person calling the function which is msg.sender
        emit Paused(msg.sender);
    }


    // the name of the function is unpause and it external that is the visibilty and onlyOwner is the response 
    function unpause() external onlyOwner {
        // where paused here is false 
        paused = false;
        // and it should emit an event whose name is unPaused with the person who is calling the function msg.sender
        emit Unpaused(msg.sender);
    }
}
