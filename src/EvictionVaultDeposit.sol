// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {EvictionVaultBase} from "./EvictionVaultBase.sol";


// the name of the contract is EvictionVaultDeposit and since it importing from EVictionVaultBase
contract EvictionVaultDeposit is EvictionVaultBase {

    

    // now a constrcutor is also used here where the address is stored in an array which measn list of address and it stored in memory
    // and the name of that variable is _owners and the threshold value has a datatype of of uint256 which is the normal thing to do
    constructor(address[] memory _owners, uint256 _threshold) 
        payable 
        EvictionVaultBase(_owners, _threshold) 
    {}
    

    // now this is used to receive where the visibilty is external and the address to receive the tokens is payable 
    receive() external payable {
        // now the balances of the msg.sender that the person about to receive is the sum of the msg.value that is to be received plus the 
        // current balance of the person calling the function
        balances[msg.sender] += msg.value;
        // so this line means that the totalVaultValue + the current value is equal to the new totalVaultValue
        //it just like saying x1 = x0 + msg.value
        totalVaultValue += msg.value;
        // and it then emitted the name of the event and the response there is the msg.sender(the person calling the function) and the value that 
        // about to be received
        emit Deposit(msg.sender, msg.value);
    }

   
    // the name of the function is deposit and the visibilty is external and the address is payable(so that it can receive money)
    function deposit() external payable {
        // so this one too the balance of the person calling the function + the value to be added 
        // x1 = x0 + msg.value
        // it like one is doing something like new raphson method 
        // there is an increment at every point
        balances[msg.sender] += msg.value;
        // the totalVaultValue is the same logic here too initial value of the totalVaultValue + the value being added which will now be 
        // equal to the final totalVaultValue
        totalVaultValue += msg.value;
        // now to emit the event the name here is Deposit and the response is the person who called the contract and the value
        emit Deposit(msg.sender, msg.value);
    }


    // now the function to withdraw 
    // and the amount to withdraw is taken as an input which has a datatype and name of the variable is amount
    // and the visibilty is externa; 
    // and the response whenNotPaused
    function withdraw(uint256 amount) external whenNotPaused {
        // if the balances of the person calling the function has a balance that greater than the amount or equal to the amount that being requested 
        // and if that condition is not met show insufficient balance as the response
        require(balances[msg.sender] >= amount, "insufficient balance");
        // now the balances of the person calling the function - amount to get the final balance of the msg.sender(person calling the function)
        balances[msg.sender] -= amount;
        // now the (totalVaultValue)i - amount = (totalVaultValue)f
        totalVaultValue -= amount;
        // payable(msg.sender) make an address to be able to receive tokens 
        // call{value: amount} the amount that address is to receive 
        // (bool success, ) the successful response if the transaction goes through 
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        // if the withdraw was not successful show this response transfer failed
        require(success, "transfer failed");
        // the name of the event Withdrawal and the the person calling the function and the amount was withdrawn
        emit Withdrawal(msg.sender, amount);
    }


}
