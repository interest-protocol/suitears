/*
* @title Linear Vesting Wallet
*
* @notice Creates a Wallet that allows the holder to claim coins linearly. 
*/
module suitears::linear_vesting_wallet {
  // === Imports ===

  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};

  use suitears::vesting::linear_vested_amount;

  // === Errors ===  

  // @dev Thrown if you try to create a Wallet with a vesting schedule that starts in the past. 
  const EInvalidStart: u64 = 0;

  // === Structs ===  

  struct Wallet<phantom T> has key, store {
    id: UID,
    // Amount of tokens to give to the holder of the wallet
    balance: Balance<T>,
    // The holder can start claiming tokens after this date. 
    start: u64,
    // Total amount of `Coin<T>` released so far. 
    released: u64,
    // The duration of the vesting. 
    duration: u64
  }

  // === Public Create Function ===  

  /*
  * @notice It creates a new {Wallet<T>}.  
  *
  * @param token A `sui::coin::Coin<T>`.
  * @param c The shared object `sui::clock::Clock`  
  * @param start Dictate when the vesting schedule starts.    
  * @param duration The duration of the vesting schedule. 
  * @return Wallet<T>.
  *
  * aborts-if:   
  * - `start` is in the past.     
  */
  public fun new<T>(token: Coin<T>, c: &Clock, start: u64, duration: u64, ctx: &mut TxContext): Wallet<T> {
    assert!(start >= clock::timestamp_ms(c), EInvalidStart);
    Wallet {
      id: object::new(ctx),
      balance: coin::into_balance(token),
      released: 0,
      start, 
      duration,
    }
  }  

  // === Public Read Function ===  

  /*
  * @notice Returns the current amount of tokens in the `self`.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun balance<T>(self: &Wallet<T>): u64 {
    balance::value(&self.balance)
  }

  /*
  * @notice Returns the start timestamp of the vesting schedule.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun start<T>(self: &Wallet<T>): u64 {
    self.start
  }  

  /*
  * @notice Returns the current amount of total released tokens from the `self`.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun released<T>(self: &Wallet<T>): u64 {
    self.released
  }

  /*
  * @notice Returns the duration of the vesting schedule.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun duration<T>(self: &Wallet<T>): u64 {
    self.duration
  }  

  /*
  * @notice Returns the current amount of coins available to the caller based on the linear schedule.  
  *
  * @param self A {Wallet<T>}.
  * @param c The `sui::clock::Clock` shared object. 
  * @return u64. A portion of the amount that can be claimed by the user. 
  */
  public fun vesting_status<T>(self: &Wallet<T>, c: &Clock): u64 {
    let vested = linear_vested_amount(
      self.start, 
      self.duration, 
      balance::value(&self.balance), 
      self.released, 
      clock::timestamp_ms(c)
    );

    vested - self.released
  }  

  // === Public Mutative Functions ===  

  /*
  * @notice Releases the current amount of coins available to the caller based on the linear schedule.  
  *
  * @param self A {Wallet<T>}.
  * @param c The `sui::clock::Clock` shared object. 
  * @return Coin<T>. 
  */
  public fun claim<T>(self: &mut Wallet<T>, c: &Clock, ctx: &mut TxContext): Coin<T> {
    // Release amount
    let releasable = vesting_status(self, c);

    *&mut self.released = self.released + releasable;

    coin::from_balance(balance::split(&mut self.balance, releasable), ctx)
  }

  /*
  * @notice Destroys a {Wallet<T>} with no balance.  
  *
  * @param self A {Wallet<T>}.
  */
  public fun destroy_zero<T>(self: Wallet<T>) {
    let Wallet { id, start: _, duration: _, balance, released: _} = self;
    object::delete(id);
    balance::destroy_zero(balance);
  }
}