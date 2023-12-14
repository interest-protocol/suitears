/*
* @title Airdrop Utils
*
* @notice Provides a verify function to validate if a leaf belongs in the tree. 
*/
module suitears::airdrop_utils {
  // === Imports ===  

  use std::vector;
  
  use sui::bcs;
  use sui::hash;
  use sui::tx_context::{Self, TxContext};

  use suitears::merkle_proof;

  // === Errors ===

  // @dev Thrown if the leaf does not belong to the tree. 
  const EInvalidProof: u64 = 0;

  // === Public View Functions ===  

  /*
  * @notice Checks if the sender is allowed to redeem an `amount` from an airdrop using Merkle proofs.  
  *
  * @param root The root of the Merkle tree.  
  * @param proof The proof that the sender can redeem the `amount` from the airdrop.  
  * @param amount Number of coins the sender can redeem.  
  * @return u256. The index of the leaf to register in the bitmap.  
  *
  * aborts-if: 
  * - keccak256([address, amount]) is not in the tree. 
  */
  public fun verify(
    root: vector<u8>,
    proof: vector<vector<u8>>, 
    amount: u64, 
    ctx: &mut TxContext
  ): u256 {
    let sender = tx_context::sender(ctx);
    let payload = bcs::to_bytes(&sender);

    vector::append(&mut payload, bcs::to_bytes(&amount));

    let leaf = hash::keccak256(&payload);
    let (pred, index) = merkle_proof::verify_with_index(&proof, root, leaf);
    
    assert!(pred, EInvalidProof);
    index 
  }
}