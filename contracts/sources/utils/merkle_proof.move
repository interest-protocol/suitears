/*
 * @title Merkle Proof. 
 *
 * @notice Allows users to verify Merkle Tree proofs. 
 *
 * @dev It is based on the OZ implementation. 
 * @dev https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol
 *
 * @dev The tree and the proofs can be generated using https://github.com/merkletreejs/merkletreejs
 *
 * @dev WARNING: You should avoid using leaf values that are 64 bytes long prior to hashing.
 *
 */
module suitears::merkle_proof {
  // === Imports ===
      
  use std::vector;

  use std::hash;

  use suitears::vectors;

  // === Public Functions ===  

  /*
  * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree defined by `root`. 
  * For this, a `proof` must be provided, containing sibling hashes on the branch from the leaf to the root of the tree. 
  * Each pair of leaves and each pair of pre-images are assumed to be sorted.
  *
  * @param proof The Merkle proof. 
  * @param root The root of the Merkle Tree. 
  * @param leaf The `leaf` we wish to prove if it is part of the tree. 
  * @return bool. If it is part of the Merkle tree. 
  */
  public fun verify(
    proof: &vector<vector<u8>>,
    root: vector<u8>,
    leaf: vector<u8>
  ): bool {
    process_proof(proof, leaf) == root
  }

  /*
  * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree defined by `root`. 
  * For this, a `proof` must be provided, containing sibling hashes on the branch from the leaf to the root of the tree. 
  * Each pair of leaves and each pair of pre-images are assumed to be sorted.
  * @dev The index logic is from ENS token: https://etherscan.io/token/0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72#code 
  *
  * @param proof The Merkle proof. 
  * @param root The root of the Merkle Tree. 
  * @param leaf The `leaf` we wish to prove if it is part of the tree. 
  * @return bool. If it is part of the Merkle tree. 
  * @return u256. The index of the `leaf`. 
  */
  public fun verify_with_index(
    proof: &vector<vector<u8>>,
    root: vector<u8>,
    leaf: vector<u8>
  ): (bool, u256) {  
    let computed_hash = leaf;
    let proof_length = vector::length(proof);
    let i = 0;
    let j = 0;

    while (i < proof_length) {
      j = j * 2;
      let proof_element = *vector::borrow(proof, i);

      computed_hash = if (vectors::lt(computed_hash, proof_element)) 
        efficient_hash(computed_hash, proof_element) 
      else {
        j = j + 1;
        efficient_hash(proof_element, computed_hash)
      };
      
      i = i + 1;
    };

    (computed_hash == root, j)
  }

  /*
  * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up from `leaf` using `proof`. 
  * A `proof` is valid if and * only if the rebuilt hash matches the root of the tree. 
  * When processing the proof, the pairs of leaves & pre-images are assumed to be sorted. 
  *
  * @param proof The Merkle proof. 
  * @param leaf The `leaf` we wish to prove if it is part of the tree. 
  * @return root. Root of the Merkle Tree.  
  */
  fun process_proof(proof: &vector<vector<u8>>, leaf: vector<u8>): vector<u8> {
    let computed_hash = leaf;
    let proof_length = vector::length(proof);
    let i = 0;

    while (i < proof_length) {
      computed_hash = hash_pair(computed_hash, *vector::borrow(proof, i));
      i = i + 1;
    };

    computed_hash
  }

  /*
  * @dev Hashes `a` and `b` in ascending order. 
  *
  * @param a Bytes to be appended and hashed. 
  * @param b Bytes to be appended and hashed. 
  * @return vector<u8>. The result of hashing `a` and `b`. 
  */
  fun hash_pair(a: vector<u8>, b: vector<u8>): vector<u8> {
    if (vectors::lt(a, b)) efficient_hash(a, b) else efficient_hash(b, a)
  }

  /*
  * @dev Concats and hashes `a` and `b`. 
  *
  * @param a Bytes to be appended and hashed. 
  * @param b Bytes to be appended and hashed. 
  * @return vector<u8>. The result of hasing `a` and `b`. 
  */
  fun efficient_hash(a: vector<u8>, b: vector<u8>): vector<u8> {
    vector::append(&mut a, b);
    hash::sha3_256(a)
  }
}