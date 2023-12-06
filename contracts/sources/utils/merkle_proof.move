/*
 * @title Merkle Proof. Allows users to verify Merkle Tree proofs. 
 *
 * @dev It is from OZ. 
 * @dev https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol
 *
 * @dev The tree and the proofs can be generated using OZ's library.abort
 * @dev https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 *
 * @dev WARNING: You should avoid using leaf values that are 64 bytes long prior to hashing, 
 * or use a hash function other than keccak256 for hashing leaves. 
 * This is because the concatenation of a sorted pair of internal nodes in the Merkle tree could be reinterpreted as a leaf
 * value. OpenZeppelin's JavaScript library generates Merkle trees that are safe against this attack out of the box.
 *
 */
module suitears::merkle_proof {
  // === Imports ===
      
  use std::vector;

  use sui::hash;

  use suitears::vectors;

  // === Errors ===  

  // @dev When an invalid multi-proof is supplied. Proof flags length must equal proof length + leaves length - 1.
  const EInvalidMultiProof: u64 = 0;

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

      computed_hash = if (vectors::lt(&computed_hash, &proof_element)) 
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
  * When processing the proof, the pairs of leafs & pre-images are assumed to be sorted. 
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
  * @dev Returns true if the `leaves` can be proved to be a part of a Merkle tree defined by 
  * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}. 
  *
  * @param proof The proof that the `leaves` belong to the the Merkle tree. 
  * @param proof_flags Instructions to reconstruct the `root`. 
  * @param root The root we wish to prove. 
  * @param leaves The leaves we are checking. 
  * @return bool. True if the `leaves` belong to a Merkle Tree with a `root`. 
  */
  public fun multi_proof_verify(
    proof: &vector<vector<u8>>,
    proof_flags: &vector<bool>,
    root: vector<u8>,
    leaves: &vector<vector<u8>>
  ): bool {
    process_multi_proof(proof, proof_flags, leaves) == root
  }

  /*
  * @dev Returns the root of a tree reconstructed from `leaves` and the sibling nodes in `proof`,
  * consuming from one or the other at each step according to the instructions given by `proofFlags`.
  *
  * @param proof The proof that the `leaves` belong to the the Merkle tree. 
  * @param proof_flags Instructions to reconstruct the `root`. 
  * @param leaves The leaves we are checking. 
  * @return root. The reconstructed root. 
  */
  fun process_multi_proof(
    proof: &vector<vector<u8>>,
    proof_flags: &vector<bool>,
    leaves: &vector<vector<u8>>,
  ): vector<u8> {
    // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
    // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
    // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
    // the merkle tree.
    let leaves_len = vector::length(leaves);
    let total_hashes = vector::length(proof_flags);

    // Check proof validity.
    assert!(leaves_len + vector::length(proof) - 1 == total_hashes, EInvalidMultiProof);

    // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
    // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
    let hashes = vector::empty<vector<u8>>();
    let leaf_pos = 0;
    let hash_pos = 0;
    let proof_pos = 0;
    // At each step, we compute the next hash using two values:
    // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
    //   get the next hash.
    // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
    //   `proof` array.
    let i = 0;

    while (i < total_hashes) {
      let a = if (leaf_pos < leaves_len) {
        leaf_pos = leaf_pos + 1;
        *vector::borrow(leaves, leaf_pos)
      } else {
        hash_pos = hash_pos + 1;
        *vector::borrow(&hashes, hash_pos)
      };

      let b = if (*vector::borrow(proof_flags, i)) {
        if (leaf_pos < leaves_len) {
          leaf_pos = leaf_pos + 1;
          *vector::borrow(leaves, leaf_pos)
        } else {
          hash_pos = hash_pos + 1;
          *vector::borrow(&hashes, hash_pos)
        }
      } else {
        proof_pos = proof_pos + 1;
        *vector::borrow(proof, proof_pos)
      };

      vector::push_back(&mut hashes, hash_pair(a, b));
      i = i + 1;
    };

    if (total_hashes > 0) {
      *vector::borrow(&hashes, total_hashes - 1)
    } else if (leaves_len > 0) {
      *vector::borrow(leaves, 0)
    } else {
      *vector::borrow(proof, 0)
    }
  }

  /*
  * @dev Hashes `a` and `b` in ascending order. 
  *
  * @param a Bytes to be appended and hashed. 
  * @param b Bytes to be appended and hashed. 
  * @return vector<u8>. The result of hasing `a` and `b`. 
  */
  fun hash_pair(a: vector<u8>, b: vector<u8>): vector<u8> {
    if (vectors::lt(&a, &b)) efficient_hash(a, b) else efficient_hash(b, a)
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
    hash::keccak256(&a)
  }
}