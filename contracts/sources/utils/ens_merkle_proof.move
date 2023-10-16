// SPDX-License-Identifier: MIT
// Based on: https://etherscan.io/token/0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72#code
module suitears::ens_merkle_proof {
    use std::hash;
    use std::vector;

    use suitears::vectors;

    /// @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
    /// defined by `root`. For this, a `proof` must be provided, containing
    /// sibling hashes on the branch from the leaf to the root of the tree. Each
    /// pair of leaves and each pair of pre-images are assumed to be sorted.
    public fun verify(
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
           else 
           {
            j = j + 1;
            efficient_hash(proof_element, computed_hash)
          };
            i = i + 1;
        };

        (computed_hash == root, j)
    }

    fun efficient_hash(a: vector<u8>, b: vector<u8>): vector<u8> {
        vector::append(&mut a, b);
        hash::sha3_256(a)
    }
}