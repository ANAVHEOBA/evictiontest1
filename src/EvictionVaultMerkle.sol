// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultDeposit} from "./EvictionVaultDeposit.sol";

contract EvictionVaultMerkle is EvictionVaultDeposit {

    constructor(address[] memory _owners, uint256 _threshold) 
        payable 
        EvictionVaultDeposit(_owners, _threshold) 
    {}

    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    function _verifyMerkleProof(
        bytes32[] calldata proof,
        bytes32 leaf
    ) internal view returns (bool) {
        bytes32 computed = leaf;
        for (uint i = 0; i < proof.length; i++) {
            computed = _hashPair(computed, proof[i]);
        }
        return computed == merkleRoot;
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _leaf(address account, uint256 amount) internal pure returns (bytes32 leaf) {
        assembly {
            mstore(0x00, account)
            mstore(0x20, amount)
            leaf := keccak256(0x0c, 0x34)
        }
    }

    function claim(bytes32[] calldata proof, uint256 amount) external whenNotPaused {
        bytes32 leaf = _leaf(msg.sender, amount);
        require(_verifyMerkleProof(proof, leaf), "invalid proof");
        require(!claimed[msg.sender], "already claimed");
        
        claimed[msg.sender] = true;
        totalVaultValue -= amount;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "claim transfer failed");
        
        emit Claim(msg.sender, amount);
    }

    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) external pure returns (bool) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        if (signature.length != 65) return false;
        
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        
        if (v < 27) v += 27;
        if (v != 27 && v != 28) return false;
        
        address recovered = ecrecover(messageHash, v, r, s);
        return recovered == signer;
    }
}
