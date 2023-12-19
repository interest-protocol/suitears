/*
* @title Airdrop
*
* @notice Pull design airdrop. It uses Merkle trees to assign a `sui::coin::Coin` amount to a user.  
* The user can submit a Merkle proof to receive his airdrop.   
*/
module suitears::airdrop {
  // === Imports ===  
  
  use std::vector;

  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID}; 
  use sui::clock::{Self, Clock};
  use sui::balance::{Self, Balance};  
  use sui::tx_context::{Self, TxContext};

  use suitears::math64;
  use suitears::airdrop_utils::verify;
  use suitears::bitmap::{Self, Bitmap};

 // === Errors ===  

  // @dev Thrown if a user tries to claim his airdrop twice. 
  const EAlreadyClaimed: u64 = 0;

  // @dev Thrown if the airdrop creator tries provides an empty Merkle tree. 
  const EInvalidRoot: u64 = 1;

  // @dev Thrown if the airdrop creator tries create an airdrop in the past.  
  const EInvalidStartTime: u64 = 2;

  // @dev Thrown if a user tries to claim the airdrop before it starts.
  const EHasNotStarted: u64 = 3;
  
  // @dev Thrown if a user submits an empty proof.
  const EInvalidProof: u64 = 4;

  // === Struct ===  

  struct Airdrop<phantom T> has key, store { 
    id: UID,
    // Total amount of airdrop coins
    balance: Balance<T>,
    // Root of the Merkle tree
    root: vector<u8>,
    // Users can claim their airdrop after this timestamp in milliseconds.  
    start: u64,
    // A Bitmap to keep track of the claimed airdrops.  
    map: Bitmap
  }

  // === Public Create Function ===    

  /*
  * @notice Creates an airdrop.  
  *
  * @param airdrop_coin The coin that will be distributed in the airdrop.  
  * @param root The Merkle tree root that keeps track of all the airdrops.   
  * @param start The start timestamp of the airdrop in milliseconds. 
  * @param c The `sui::clock::Clock` shared object.     
  * @return Airdrop<T>  
  *
  * aborts-if: 
  * - The `root` is empty.  
  * - The `start` is in the past.  
  */
  public fun new<T>(airdrop_coin: Coin<T>, root: vector<u8>, start: u64, c: &Clock, ctx: &mut TxContext): Airdrop<T> {
    assert!(start >= clock::timestamp_ms(c), EInvalidStartTime);
    assert!(!vector::is_empty(&root), EInvalidRoot);
    Airdrop {
        id: object::new(ctx),
        balance: coin::into_balance(airdrop_coin),
        root,
        start,
        map: bitmap::new(ctx)
    }
  }

  // === Public View Functions ===     

  /*
  * @notice Returns the current amount of coins in the `self`.  
  *
  * @param self The shared {Airdrop<T>} object.  
  * @return u64.  
  */
  public fun balance<T>(self: &Airdrop<T>): u64 {
    balance::value(&self.balance)
  }

  /*
  * @notice Returns the root of the Merkle tree for the airdrop `self`.  
  *
  * @param self The shared {Airdrop<T>} object.  
  * @return vector<u8>.  
  */
  public fun root<T>(self: &Airdrop<T>): vector<u8> {
    self.root
  }

  /*
  * @notice Returns the start timestamp of the airdrop. Users can claim after this date.   
  *
  * @param self The shared {Airdrop<T>} object.  
  * @return u64.  
  */
  public fun start<T>(self: &Airdrop<T>): u64 {
    self.start
  }

  /*
  * @notice Returns a {Bitmap} that keeps track of the claimed airdrops.   
  *
  * @param self The shared {Airdrop<T>} object.  
  * @return &Bitmap.  
  */
  public fun borrow_map<T>(self: &Airdrop<T>): &Bitmap {
    &self.map
  }

  /*
  * @notice Checks if a user has already claimed his airdrop.
  *
  * @param self The shared {Airdrop<T>} object.  
  * @param proof The proof that the sender can redeem the `amount` from the airdrop.  
  * @param amount Number of coins the sender can redeem.  
  * @param address A user address.  
  * @return bool. True if he has claimed the airdrop already.  
  *
  * aborts-if: 
  * - If the `proof` is not valid. 
  */
  public fun has_account_claimed<T>(
    self: &Airdrop<T>,
    proof: vector<vector<u8>>, 
    amount: u64, 
    user: address
  ): bool {
    bitmap::get(&self.map, verify(self.root, proof, amount, user))
  }  

  // === Public Mutative Functions ===     

  /*
  * @notice Allows a user to claim his airdrop by proving a Merkle proof.   
  *
  * @param self The shared {Airdrop<T>} object.  
  * @param proof The proof that the sender can redeem the `amount` from the airdrop.  
  * @param c The `sui::clock::Clock` shared object.     
  * @param amount Number of coins the sender can redeem.  
  * @return Coin<T>. The airdrop Coin.  
  *
  * aborts-if: 
  * - The `proof` is not valid. 
  * - The airdrop has not started yet.
  * - The user already claimed it
  */
  public fun get_airdrop<T>(
    self: &mut Airdrop<T>, 
    proof: vector<vector<u8>>, 
    c: &Clock,
    amount: u64, 
    ctx: &mut TxContext
  ): Coin<T> {
    assert!(clock::timestamp_ms(c) >= self.start, EHasNotStarted);
    assert!(!vector::is_empty(&proof), EInvalidProof);

    let index = verify(self.root, proof, amount, tx_context::sender(ctx));

    assert!(!bitmap::get(&self.map, index), EAlreadyClaimed);

    bitmap::set(&mut self.map, index);
    let current_balance = balance::value(&self.balance);

    coin::take(&mut self.balance, math64::min(amount, current_balance), ctx)
  }

  /*
  * @notice Destroys an empty {Airdrop<T>} shared object.     
  *
  * @param self The shared {Airdrop<T>} object.  
  *
  * aborts-if: 
  * - The `self` has left over coins.
  */
  public fun destroy_zero<T>(self: Airdrop<T>) {
    let Airdrop {id, balance, start: _, root: _, map} = self;
    object::delete(id);
    balance::destroy_zero(balance);
    bitmap::destroy(map);
  }
}