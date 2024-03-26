/*
* @title Box
*
* @notice Wraps a struct with the store ability to provide access control via `suitears::owner::OwnerCap`. 
*
* @dev Wraps a struct with the store in a `Box<T>` object to allow anyone to {borrow} `T` but only the module with the witness to {borrow_mut}.
* @dev It can be used to safely share a struct with the store because it ensures that only the cap holder can update it while anyone else can read it.
*/
module suitears::box {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  use suitears::owner::{Self, OwnerCap};

  // === Structs ===

  struct Box<T: store> has key, store {
    id: UID,
    // Wrapped `T`
    content: T
  }

  struct BoxWitness has drop {}

  // === Public Create Functions ===  

  /*
  * @notice It creates an {OwnerCap<BoxWitness>}. 
  * It is used to provide admin capabilities to the holder.
  *
  * @return {OwnerCap<BoxWitness>}. 
  */
  public fun new_cap(ctx: &mut TxContext): OwnerCap<BoxWitness> {
    owner::new(BoxWitness {}, vector[], ctx)
  }

  /*
  * @notice Wraps a `content` in a `Box<T>`. 
  *
  * @param cap A `suitears::owner::OwnerCap` that will be given the access rights for the newly created `Box<T>`. 
  * @param content An object with the store ability.
  * @return `Box<T>`. The wrapped `content`.  
  */
  public fun new<T: store>(cap: &mut OwnerCap<BoxWitness>, content: T, ctx: &mut TxContext): Box<T> {
    let box = Box {
      id: object::new(ctx),
      content
    };

    owner::add(cap, BoxWitness {}, object::id(&box));

    box
  }

  // === Public Access Functions ===   

  /*
  * @notice Returns an immutable reference to the `self.content`. 
  *
  * @param self A reference to the wrapped content. 
  * @return &T. An immutable reference to `T`.  
  */
  public fun borrow<T: store>(self: &Box<T>): &T {
    &self.content
  }

  /*
  * @notice Returns a mutable reference to the `self.content`. 
  *
  * @param self The wrapped content. 
  * @param cap The `suitears::owner::OwnerCap` of the `self`. 
  * @return &mut T. A mutable reference to `T`.  
  */
  public fun borrow_mut<T: store>(self: &mut Box<T>, cap: &OwnerCap<BoxWitness>): &mut T {
    owner::assert_ownership(cap, object::id(self));
    &mut self.content
  }

  /*
  * @notice Returns a mutable reference to the `self.content.id`. 
  *
  * @param self The wrapped content. 
  * @param cap The `suitears::owner::OwnerCap` of the `self`. 
  * @return &mut UID. A mutable reference to `T` id.  
  */
  public fun borrow_mut_uid<T: store>(self: &mut Box<T>, cap: &OwnerCap<BoxWitness>): &mut UID {
    owner::assert_ownership(cap, object::id(self));
    &mut self.id
  }

  // === Public Destroy Functions ===     

  /*
  * @notice Destroys the wrapped struct `Box<T>` and returns the inner `T`. 
  *
  * @param self The wrapped content. 
  * @param cap The `suitears::owner::OwnerCap` of the `self`. 
  * @return T. The inner content.  
  */
  public fun destroy<T: store>(self: Box<T>, cap: &OwnerCap<BoxWitness>): T {
    owner::assert_ownership(cap, object::id(&self));
    let Box { id, content } = self;
    object::delete(id);
    content
  }

  /*
  * @notice Drops the wrapped struct `Box<T>` and `T`. 
  *
  * @param self The wrapped content. 
  * @param cap The `suitears::owner::OwnerCap` of the `self`. 
  */
  public fun drop<T: store + drop>(self: Box<T>, cap: &OwnerCap<BoxWitness>) {
    owner::assert_ownership(cap, object::id(&self));
    let Box { id, content: _ } = self;
    object::delete(id);
  }  
}