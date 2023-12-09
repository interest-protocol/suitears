/*
* @title Owner
*
* @notice Capability that provides access control to objects via their `sui::object::ID`.
*/
module suitears::owner {
  // === Imports ===  

  use std::vector;

  use sui::tx_context::TxContext;
  use sui::object::{Self, UID, ID};

  // === Errors ===
  
  const ENotAllowed: u64 = 0;

  // === Structs ===

  struct OwnerCap<phantom T> has key, store {
    id: UID,
    // Vector of `sui::object::ID` that this capability owns. 
    of: vector<ID>
  }

  // === Public Create Function ===  

  /*
  * @notice Creates an {OwnerCap<T>}.
  *
  * @dev The witness `T` is to make the {OwnerCap} unique per module.   
  *
  * @param _ A witness to tie this {OwnerCap<T>} with the module that owns the witness.
  * @param of Vector of `sui::object::ID` that this capability owns.
  * @return {OwnerCap<T>}.  
  */
  public fun new<T: drop>(_: T, of: vector<ID>, ctx: &mut TxContext): OwnerCap<T> {
    OwnerCap {
      id: object::new(ctx),
      of
    }
  }

  // === Public Read Functions === 

  /*
  * @notice Checks if the `self` owns `x`.
  *
  * @param self A {OwnerCap<T>} object. 
  * @param x The `sui::object::ID` of an object. 
  * @return bool. True if the `self` owns `x`. 
  */
  public fun contains<T: drop>(self: &OwnerCap<T>, x: ID): bool {
    vector::contains(&self.of, &x)
  }

  /*
  * @notice returns the vector of the `sui::object::ID` that the `self` owns.
  *
  * @param self A {CoinDecimals} object. 
  * @return vector<ID>. The vector of `sui::object::ID`. 
  */
  public fun of<T: drop>(self: &OwnerCap<T>): vector<ID> {
    self.of
  }

  // === Public Mutate Function ===    

  /*
  * @notice Adds `x` to `self`.
  *
  * @dev It does not abort if it has been added already. 
  *
  * @param _ A witness to make sure only the module can `sui::object::ID` to the self.
  * @param self A {CoinDecimals} object. 
  * @param coin_metadata The `sui::coin::CoinMetadata` of a coin with type `CoinType`. 
  */
  public fun add<T: drop>(_: T, self: &mut OwnerCap<T>, x: ID) {
    if (vector::contains(&self.of, &x)) return;
    vector::push_back(&mut self.of, x);
  }

  public fun remove<T: drop>(_: T, self: &mut OwnerCap<T>, x: ID) {
    let (present, i) = vector::index_of(&self.of, &x);
    if (!present) return;
    vector::remove(&mut self.of, i);
  }

  public fun destroy<T: drop>(self: OwnerCap<T>) {
    let  OwnerCap { id, of: _ } = self; 
    object::delete(id);
  }

  public fun destroy_empty<T>(self: OwnerCap<T>) {
    let  OwnerCap { id, of} = self; 
    object::delete(id);
    vector::destroy_empty(of);
  }


  public fun assert_ownership<T: drop>(self: &OwnerCap<T>, x: ID) {
    assert!(contains(self, x), ENotAllowed);
  }  
}