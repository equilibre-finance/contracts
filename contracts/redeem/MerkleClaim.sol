// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

/// ============ Imports ============

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IVara} from "contracts/interfaces/IVara.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol"; // OZ: MerkleProof

/// @title MerkleClaim
/// @notice Claims VARA for members of a merkle tree
/// @author Modified from Merkle Airdrop Starter (https://github.com/Anish-Agnihotri/merkle-airdrop-starter/blob/master/contracts/src/MerkleClaimERC20.sol)
contract MerkleClaim is Initializable {
    /// ============ Immutable storage ============

    /// @notice VARA token to claim
    IVara public VARA;
    /// @notice ERC20-claimee inclusion root
    bytes32 public merkleRoot;

    /// ============ Mutable storage ============

    /// @notice Mapping of addresses who have claimed tokens
    mapping(address => bool) public hasClaimed;

    /// ============ Constructor ============

    /// @notice Creates a new MerkleClaim contract
    /// @param _vara address
    /// @param _merkleRoot of claimees
    function initialize(
        address _vara, 
        bytes32 _merkleRoot
    ) external initializer {
        VARA = IVara(_vara);
        merkleRoot = _merkleRoot;
    }

    /// ============ Events ============

    /// @notice Emitted after a successful token claim
    /// @param to recipient of claim
    /// @param amount of tokens claimed
    event Claim(address indexed to, uint256 amount);

    /// ============ Functions ============

    /// @notice Allows claiming tokens if address is part of merkle tree
    /// @param amount of tokens owed to claimee
    /// @param proof merkle proof to prove address and amount are in tree
    function claim(
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        // Throw if address has already claimed tokens
        require(!hasClaimed[msg.sender], "ALREADY_CLAIMED");

        // Verify merkle proof, or revert if not in tree
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        bool isValidLeaf = MerkleProofUpgradeable.verify(proof, merkleRoot, leaf);
        require(isValidLeaf, "NOT_IN_MERKLE");

        // Set address to claimed
        hasClaimed[msg.sender] = true;

        // Claim tokens for address
        require(VARA.claim(msg.sender, amount), "CLAIM_FAILED");

        // Emit claim event
        emit Claim(msg.sender, amount);
    }
}
