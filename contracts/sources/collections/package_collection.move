/*
* @title Package Collection
*
* @notice Provides access control to an object for the whole package where is has been created. To be replaced with `fun(package)` in Move 2024.
*
* @dev Wraps a collection in a `PackageCollection<C>` object to allow anyone to {borrow} `C` but only modules from the same package to {borrow_mut}.
* @dev It can be used to share a Collection of your User's account information with the network and ensure that only your protocol can update it while anyone else can read it.
*/
module suitears::package_collection {
  // === Imports ===

  use std::type_name;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  // === Errors === 

  const EDifferentPackage: u64 = 0;

  // === Structs ===

  struct PackageCollection<C> has key, store {
    id: UID,
    // Wrapped collection
    collection: C
  }

  // === Public Create Functions ===  

  /*
  * @notice Wraps a `collection` in a `PackageCollection<C>`. 
  *
  * @param collection An object with the store ability.
  * @return `PackageCollection<C>`. The wrapped `collection`.  
  */
  public fun new<C: store>(collection: C, ctx: &mut TxContext): PackageCollection<C> {
    PackageCollection {
      id: object::new(ctx),
      collection
    }
  }

  // === Public Access Functions ===   

  /*
  * @notice Returns an immutable reference to the `self.collection`. 
  *
  * @param self A reference to the wrapped collection. 
  * @return &C. An immutable reference to `C`.  
  */
  public fun borrow<C: store>(self: &PackageCollection<C>): &C {
    &self.collection
  }

  /*
  * @notice Returns a mutable reference to the `self.collection`. 
  *
  * @param self The wrapped collection. 
  * @return &mut C. A mutable reference to `C`.  
  */
  public fun borrow_mut<C: store>(self: &mut PackageCollection<C>): &mut C {
    &mut self.collection
  }

  /*
  * @notice Returns a mutable reference to the `self.collection.id`. 
  *
  * @param self The wrapped collection. 
  * @return &mut UID. A mutable reference to `C` id.  
  */
  public fun borrow_mut_uid<C: store>(self: &mut PackageCollection<C>): &mut UID {
    &mut self.id
  }

  // === Public Destroy Functions ===     

  /*
  * @notice Destroys the wrapped struct `PackageCollection<C>` and returns the inner `C`. 
  *
  * @param self The wrapped collection. 
  * @return C. The inner collection.  
  */
  public fun destroy<C: store>(self: PackageCollection<C>): C {
    let PackageCollection { id, collection } = self;
    object::delete(id);
    collection
  }

  /*
  * @notice Drops the wrapped struct `PackageCollection<C>` and `C`. 
  *
  * @param self The wrapped collection. 
  */
  public fun drop<C: store + drop>(self: PackageCollection<C>) {
    let PackageCollection { id, collection: _ } = self;
    object::delete(id);
  }  

  /*
  * @notice Asserts that the module calling this function and passing the witness is from the same package as the collection
  *
  * @param _self The wrapped collection. 
  * @param _ The witness `W` in the "friend" module. 
  */
  public fun assert_same_package<C: store, W: drop>(_self: &PackageCollection<C>, _: W) {
    let collection_type_name = type_name::get<C>();
    let collection_package_id = type_name::get_address(&collection_type_name);

    let witness_type_name = type_name::get<W>();
    let witness_package_id = type_name::get_address(&witness_type_name);

    assert!(collection_package_id == witness_package_id, EDifferentPackage);
  }  
}