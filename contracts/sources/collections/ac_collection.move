/*
* @title Access Control Collection
*
* @notice Provides access control to an object via a capability.
*
* @dev Wraps a collection in a `AcCollection<C>` object to allow anyone to {borrow} `C` but only the owner to {borrow_mut}.
*/
module suitears::ac_collection {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  use suitears::owner::{Self, OwnerCap};

  // === Structs ===

  // @dev Wrapper to provide access control to the collection. 
  struct AcCollection<C> has key, store {
    id: UID,
    // Any struct with the store key. 
    collection: C
  }

  // @dev A witness to create a custom {OwnerCap<T>}. 
  struct AcCollectionWitness has drop {}

 // === Public Create Functions ===  

  /*
  * @notice Wraps a `collection` in a `AcCollection<C>` and creates its {OwnerCap}. 
  *
  * @param collection An object with the store ability.
  * @return OwnerCap<AcCollectionWitness>. A capability to {borrow_mut} and {borrow_mut_uid}. 
  * @return AcCollection<C>. The wrapped `collection`.  
  */
  public fun new<C: store>(collection: C, ctx: &mut TxContext): (OwnerCap<AcCollectionWitness>, AcCollection<C>) {
    let cap_collection = AcCollection<C> {
      id: object::new(ctx),
      collection
    };

    (
      owner::create(AcCollectionWitness {}, vector[object::id(&cap_collection)], ctx), 
      cap_collection
    )
  }

  /*
  * @notice Wraps a `collection` in a `AcCollection<C>` and assigns the ownership to `cap`. 
  *
  * @param collection An object with the store ability.
  * @param cap A mutable reference to an {OwnerCap}. 
  * @return AcCollection<C>. The wrapped `collection`.  
  */
  public fun new_with_cap<C: store>(collection: C, cap: &mut OwnerCap<AcCollectionWitness>, ctx: &mut TxContext): AcCollection<C> {
    let cap_collection = AcCollection<C> {
      id: object::new(ctx),
      collection
    };

    owner::add(AcCollectionWitness {}, cap, object::id(&cap_collection));

    cap_collection
  }

  // === Public Access Functions === 

  /*
  * @notice Returns an immutable reference to the `self.collection`. 
  *
  * @param self A reference to the wrapped collection. 
  * @return &C. An immutable reference to `C`.  
  */
  public fun borrow<C: store>(self: &AcCollection<C>): &C {
    &self.collection
  }

  /*
  * @notice Returns a mutable reference to the `self.collection`. 
  *
  * @param self The wrapped collection. 
  * @param cap A reference to the `AcCollection<C>`'s {OwnerCap}.
  * @return &mut C. A mutable reference to `C`.  
  *
  * aborts-if 
  * - `cap` is not the owner of `self`. 
  */
  public fun borrow_mut<C: store>(self: &mut AcCollection<C>, cap: &OwnerCap<AcCollectionWitness>): &mut C {
    owner::assert_ownership(cap, object::id(self));
    &mut self.collection
  }

  /*
  * @notice Returns a mutable reference to the `self.collection.id`. 
  *
  * @param self The wrapped collection. 
  * @param cap A reference to the `AcCollection<C>`'s {OwnerCap}.
  * @return &mut UID. A mutable reference to `C` id.  
  *
  * aborts-if 
  * - `cap` is not the owner of `self`. 
  */
  public fun borrow_mut_uid<C: store>(self: &mut AcCollection<C>, cap: &OwnerCap<AcCollectionWitness>): &mut UID {
    owner::assert_ownership(cap, object::id(self));
    &mut self.id
  }

  // === Public Destroy Functions ===   

  /*
  * @notice Destroys the wrapped struct `AcCollection<C>` and returns the inner `C`. 
  *
  * @param self The wrapped collection. 
  * @param cap A reference to the `AcCollection<C>`'s {OwnerCap}.
  * @return C. The inner collection.  
  *
  * aborts-if 
  * - `cap` is not the owner of `self`. 
  */
  public fun destroy<C: store>(self: AcCollection<C>, cap: &OwnerCap<AcCollectionWitness>): C {
    owner::assert_ownership(cap, object::id(&self));
    let AcCollection { id, collection } = self;
    object::delete(id);
    collection
  }

  /*
  * @notice Drops the wrapped struct `AcCollection<C>` and `C`. 
  *
  * @param self The wrapped collection. 
  * @param cap A reference to the `AcCollection<C>`'s {OwnerCap}.
  * @return C. The inner collection.  
  *
  * aborts-if 
  * - `cap` is not the owner of `self`. 
  */
  public fun drop<C: store + drop>(self: AcCollection<C>, cap: &OwnerCap<AcCollectionWitness>) {
    owner::assert_ownership(cap, object::id(&self));
    let AcCollection { id, collection } = self;
    object::delete(id);
  }  
}