/*
* @title Permanent Lock
*
* @notice Locks any object with the store ability forever. The lock can be opened temporarily after the `time_delay`.    
*
* @dev We do not provide a function to read the data inside the {PermanentLock<T>} to prevent capabilities from being used. 
*/
module suitears::permanent_lock {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;

  // === Errors ===

  // @dev Thrown if one tries to lock an object for 0 seconds. 
  const EInvalidTime: u64 = 0;
  // @dev Thrown if one tries to temporarily unlock the data before the `time_delay`. 
  const ETooEarly: u64 = 1;

  // === Structs ===   

  struct PermanentLock<T: store> has key, store {
    id: UID,
    // The timestamp in which the `data` was locked. 
    start: u64,
    // The amount of time in milliseconds until the lock can be opened temporarily. 
    time_delay: u64,
    // An object with the store ability
    data: T,
  }

  // Hot Potatoe to force the data to be locked again. 
  struct Temporary<phantom T> {
    // The `data` is relocked using the previous `time_delay`. 
    time_delay: u64, 
  }

  // === Public View Functions ===      

  /*
  * @notice Returns the time at which this lock was created. 
  *
  * @param self A {PermanentLock<T>} 
  * @return u64. The `self.start`.  
  */
  public fun start<T: store>(self: &PermanentLock<T>): u64 {
    self.start
  }

  /*
  * @notice Returns how long until this lock can be opened temporarily. 
  *
  * @dev To find the current unlock time you must add the `self.start` with `self.time_delay`.  
  *
  * @param self A {PermanentLock<T>} 
  * @return u64. The `self.time_delay`.  
  */
  public fun time_delay<T: store>(self: &PermanentLock<T>): u64 {
    self.time_delay
  }

  /*
  * @notice Returns the time at which this lock can be opened temporarily. 
  *
  * @param self A {PermanentLock<T>} 
  * @return u64. `self.start` + `self.time_delay`.  
  */
  public fun unlock_time<T: store>(self: &PermanentLock<T>): u64 {
    self.start + self.time_delay
  }

  // === Public Mutative Function ===       

  /*
  * @notice Locks the `data` forever. However, the {PermanentLock<T>} can be often once every period.  
  *
  * @param data An object with the store ability.  
  * @param c The shared `sui::clock::Clock` object.   
  * @patam time_delay Unlock intervals.  
  * @return {Permanent<T>}.
  *
  * aborts-if
  * - `time_delay` is zero.    
  */
  public fun lock<T: store>(
    data: T,
    c: &Clock,
    time_delay: u64,
    ctx: &mut TxContext
  ): PermanentLock<T> {
    // It makes no sense to lock in the past
    assert!(time_delay != 0, EInvalidTime);

    PermanentLock {
      id: object::new(ctx),
      data,
      start: clock::timestamp_ms(c),
      time_delay
    }
  }

  /*
  * @notice Unlocks the {PermanentLock<T>} temporarily and returns the locked `T`.  
  *
  * @param self A {PermanentLock<T>} 
  * @param c The shared `sui::clock::Clock` object.   
  * @return T. The previously locked object with the store ability.  
  * @return Temporary<T>. A hot potato that must be destroyed by calling the function {relock}.  
  *
  * aborts-if
  * - `self.start` + `self.time_delay` is in the future.    
  */
  public fun unlock_temporarily<T: store>(self: PermanentLock<T>, c: &Clock): (T, Temporary<T>) {
    let PermanentLock { data, start, id, time_delay } = self;

    assert!(clock::timestamp_ms(c) >= start + time_delay, ETooEarly);

    object::delete(id);

   (data, Temporary { time_delay })
  }

  /*
  * @notice Relocks the data `T` and destroys the hot potato `temporary`.  
  *
  * @param data An object with the store ability.  
  * @param c The shared `sui::clock::Clock` object.   
  * @patam temporary Hot potato.  
  * @return {Permanent<T>}.   
  */
  public fun relock<T: store>(
    data: T, 
    c: &Clock, 
    temporary: Temporary<T>,
    ctx: &mut TxContext
  ): PermanentLock<T> {
    let Temporary { time_delay } = temporary;

    PermanentLock {
      id: object::new(ctx),
      data,
      start: clock::timestamp_ms(c),
      time_delay
    }
  }
}