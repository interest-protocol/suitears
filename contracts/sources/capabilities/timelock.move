/*
* @title Timelock
*
* @notice Locks any object with the store ability for a specific amount of time. 
*
* @dev We do not provide a function to read the data inside the {Timelock<T>} to prevent capabilities from being used. 
*/
module suitears::timelock {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;

  // === Errors ===

  // @dev Thrown if one tries to lock an object in the past. 
  const EInvalidTime: u64 = 0;
  
  // @dev Thrown if one tries to {unlock} the {Timelock} before the `unlock_time`. 
  const ETooEarly: u64 = 1;

  // === Struct ===  

  struct Timelock<T: store> has key, store {
    id: UID,
    // The unlock time in milliseconds. 
    unlock_time: u64,
    // Any object with the store ability. 
    data: T,
  }

  // === Public View Function ===      

  /*
  * @notice Returns the unlock time in milliseconds. 
  *
  * @param self A {Timelock<T>} 
  * @return u64. The `self.unlock_time`.  
  */
  public fun unlock_time<T: store>(self: &Timelock<T>): u64 {
    self.unlock_time
  }  

  // === Public Mutative Function ===     

  /*
  * @notice Locks the `data` for `unlock_time` milliseconds.  
  *
  * @param data An object with the store ability.  
  * @param c The shared `sui::clock::Clock` object.   
  * @patam unlock_time The lock period in milliseconds.  
  * @return {Timelock<T>}.
  *
  * aborts-if
  * - `unlock_time` is in the past.    
  */
  public fun lock<T: store>(
    data: T, 
    c: &Clock,
    unlock_time: u64,
    ctx: &mut TxContext
  ): Timelock<T> {
    // It makes no sense to lock in the past
    assert!(unlock_time > clock::timestamp_ms(c), EInvalidTime);

    Timelock {
      id: object::new(ctx),
      data,
      unlock_time
    }
  }

  /*
  * @notice Unlocks a {Timelock<T>} and returns the locked resource `T`.  
  *
  * @param self A {Timelock<T>} 
  * @param c The shared `sui::clock::Clock` object.   
  * @return `T`. An object with the store ability.   
  *
  * aborts-if
  * - `unlock_time` has not passed.    
  */
  public fun unlock<T: store>(self: Timelock<T>, c:&Clock): T {
    let Timelock { data, unlock_time, id } = self;

    assert!(clock::timestamp_ms(c) >= unlock_time, ETooEarly);

    object::delete(id);

    data
  }
}