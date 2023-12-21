/*
* @title Owner
*
* @dev It uses `sui::vec_set::VecSet` to prevent duplicated IDs inside {OwnerCap}. 
*
* @notice Capability that provides access control to objects via their `sui::object::ID`.
*/
module suitears::owner {
  // === Imports ===  

  use std::vector;

  use sui::tx_context::TxContext;
  use sui::vec_set::{Self, VecSet};
  use sui::object::{Self, UID, ID};

  // === Errors ===
  
  // @dev Thrown when the {OwnerCap} does not own a `sui::object::ID`. 
  const ENotAllowed: u64 = 0;

  // === Structs ===

  struct OwnerCap<phantom T> has key, store {
    id: UID,
    // VecSet of `sui::object::ID` that this capability owns. 
    of: VecSet<ID>
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
    let length = vector::length(&of);
    let set = vec_set::empty();
    let i = 0;
    while (length > i) {
      vec_set::insert(&mut set, *vector::borrow(&of, i));
      i = i + 1;
    };

    OwnerCap {
      id: object::new(ctx),
      of: set
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
    vec_set::contains(&self.of, &x)
  }

  /*
  * @notice returns the vector of the `sui::object::ID` that the `self` owns.
  *
  * @param self A {OwnerCap<T>} object. 
  * @return vector<ID>. The vector of `sui::object::ID`. 
  */
  public fun of<T: drop>(self: &OwnerCap<T>): vector<ID> {
    *vec_set::keys(&self.of)
  }

  // === Public Mutative Function ===    

  /*
  * @notice Assigns the `self` {OwnerCap<T>} as the owner of `x`.
  *
  * @dev It does not abort if it has been added already. 
  *
  * @param self A {OwnerCap<T>} object. 
  * @param _ A witness to make sure only the right module can add the `sui::object::ID` to the self.
  * @param x The `sui::object::ID` of the object, which the `self` will have ownership rights to. 
  */
  public fun add<T: drop>(self: &mut OwnerCap<T>, _: T, x: ID) {
    if (vec_set::contains(&self.of, &x)) return;
    vec_set::insert(&mut self.of, x);
  }

  /*
  * @notice Removes the `self` {OwnerCap<T>} as the owner of `x`.
  *
  * @dev It does not abort if it has already been removed. 
  *
  * @param self A {OwnerCap<T>} object. 
  * @param _ A witness to make sure only the right module can remove the `sui::object::ID` from the self.
  * @param x The `sui::object::ID` of the object, which the `self` will lose its ownership rights to. 
  */
  public fun remove<T: drop>(self: &mut OwnerCap<T>, _: T, x: ID) {
    if (!vec_set::contains(&self.of, &x)) return;
    vec_set::remove(&mut self.of, &x);
  }

  // === Public Destroy Functions ===    

  /*
  * @notice Destroys an {OwnerCap<T>}.
  *
  * @dev This capability might own several `sui::object::ID`. 
  *
  * @param self A {OwnerCap<T>} object. 
  */
  public fun destroy<T: drop>(self: OwnerCap<T>) {
    let  OwnerCap { id, of: _ } = self; 
    object::delete(id);
  }

  /*
  * @notice Destroys an {OwnerCap<T>}.
  *
  * @dev It ensures that the `self` does not own any `sui::object::ID`. 
  *
  * @param self A {OwnerCap<T>} object. 
  */
  public fun destroy_empty<T>(self: OwnerCap<T>) {
    let  OwnerCap { id, of} = self; 
    object::delete(id);
    vector::destroy_empty(vec_set::into_keys(of));
  }

  // === Public Assert Function ===    

  /*
  * @notice Checks that the `self` owns `x`.
  *
  * @param self A {OwnerCap<T>} object. 
  * @param x An `sui::object::ID`.
  *
  * aborts-if 
  * - `x` is not present in the `self.of` 
  */
  public fun assert_ownership<T: drop>(self: &OwnerCap<T>, x: ID) {
    assert!(contains(self, x), ENotAllowed);
  }  
}