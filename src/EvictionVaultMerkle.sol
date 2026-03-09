// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EvictionVaultDeposit} from "./EvictionVaultDeposit.sol";

contract EvictionVaultMerkle is EvictionVaultDeposit {
    constructor(address[] memory initialCouncil, uint256 minApprovals) payable EvictionVaultDeposit(initialCouncil, minApprovals) {}

    function setMerkleRoot(bytes32 root) external onlyOwner {
        payoutRoot = root;
        emit MerkleRootSet(root);
    }

    function _leaf(address account, uint256 amount) internal pure returns (bytes32 leaf) {
        assembly {
            mstore(0x00, account)
            mstore(0x20, amount)
            leaf := keccak256(0x0c, 0x34)
        }
    }

    function claim(bytes32[] calldata proof, uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "zero amount");

        bytes32 leaf = _leaf(msg.sender, amount);
        require(MerkleProof.verifyCalldata(proof, payoutRoot, leaf), "invalid proof");
        require(!hasClaimedPayout[msg.sender], "already claimed");
        require(trackedVaultBalance >= amount, "insufficient vault value");

        hasClaimedPayout[msg.sender] = true;
        trackedVaultBalance -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "claim transfer failed");

        emit Claim(msg.sender, amount);
    }

    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) external pure returns (bool) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(messageHash, signature);
        return err == ECDSA.RecoverError.NoError && recovered == signer;
    }
}
