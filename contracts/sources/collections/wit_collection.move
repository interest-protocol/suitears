/*
* @title Witness Collection
*
* @notice Provides access control to an object via a witness.
*
* @dev Wraps a collection in a `WitCollection<W, C>` object to allow anyone to {borrow} `C` but only the module with the witness to {borrow_mut}.
* @dev It can be used to share a Collection of your User's account information with the network and ensure that only your protocol can update it while anyone else can read it.
*/
module suitears::wit_collection {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  // === Structs ===

  struct WitCollection<phantom W, C> has key, store {
    id: UID,
    // Wrapped collection
    collection: C
  }

  // === Public Create Functions ===  

  /*
  * @notice Wraps a `collection` in a `WitCollection<W, C>`. 
  *
  * @param _ A witness that will provide access control to the `WitCollection<W, C>` via its type parameters. 
  * @param collection An object with the store ability.
  * @return `WitCollection<W, C>`. The wrapped `collection`.  
  */
  public fun new<W: drop, C: store>(_: W, collection: C, ctx: &mut TxContext): WitCollection<W, C> {
    WitCollection {
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
  public fun borrow<W: drop, C: store>(self: &WitCollection<W, C>): &C {
    &self.collection
  }

  /*
  * @notice Returns a mutable reference to the `self.collection`. 
  *
  * @param self The wrapped collection. 
  * @param _ The witness `W` in the `WitCollection<W, C>`.
  * @return &mut C. A mutable reference to `C`.  
  */
  public fun borrow_mut<W: drop, C: store>(self: &mut WitCollection<W, C>, _: W): &mut C {
    &mut self.collection
  }

  /*
  * @notice Returns a mutable reference to the `self.collection.id`. 
  *
  * @param self The wrapped collection. 
  * @param _ The witness `W` in the `WitCollection<W, C>`.
  * @return &mut UID. A mutable reference to `C` id.  
  */
  public fun borrow_mut_uid<W: drop, C: store>(self: &mut WitCollection<W, C>, _: W): &mut UID {
    &mut self.id
  }

  // === Public Destroy Functions ===     

  /*
  * @notice Destroys the wrapped struct `WitCollection<W, C>` and returns the inner `C`. 
  *
  * @param self The wrapped collection. 
  * @param _ The witness `W` in the `WitCollection<W, C>`.
  * @return C. The inner collection.  
  */
  public fun destroy<W: drop, C: store>(self: WitCollection<W, C>, _: W): C {
    let WitCollection { id, collection } = self;
    object::delete(id);
    collection
  }

  /*
  * @notice Drops the wrapped struct `AcCollection<C>` and `C`. 
  *
  * @param self The wrapped collection. 
  * @param _ The witness `W` in the `WitCollection<W, C>`.
  * @return C. The inner collection.  
  */
  public fun drop<W: drop, C: store + drop>(self: WitCollection<W, C>, _: W) {
    let WitCollection { id, collection } = self;
    object::delete(id);
  }  
}