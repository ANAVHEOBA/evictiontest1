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
    // and the amount to withdraw is taken as an input which has a datatype and variable n
    function withdraw(uint256 amount) external whenNotPaused {
        require(balances[msg.sender] >= amount, "insufficient balance");
        balances[msg.sender] -= amount;
        totalVaultValue -= amount;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }


}
