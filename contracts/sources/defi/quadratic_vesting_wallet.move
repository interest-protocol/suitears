module suitears::quadratic_vesting_wallet {
  
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};

  use suitears::vesting::quadratic_vested_amount;

  const EInvalidStart: u64 = 0;

  struct Wallet<phantom T> has key, store {
    id: UID,
    balance: Balance<T>,
    released: u64,
    vesting_curve_a: u64,
    vesting_curve_b: u64,
    vesting_curve_c: u64,
    start: u64,
    cliff: u64,
    duration: u64
  }

  public fun new<T>(
    token: Coin<T>, 
    c: &Clock, 
    vesting_curve_a: u64,
    vesting_curve_b: u64,
    vesting_curve_c: u64,
    start: u64,
    cliff: u64,
    duration: u64,
    ctx: &mut TxContext
  ): Wallet<T> {
    assert!(start >= clock::timestamp_ms(c), EInvalidStart);
    Wallet {
      id: object::new(ctx),
      balance: coin::into_balance(token),
      released: 0,
      start, 
      duration,
      vesting_curve_a,
      vesting_curve_b,
      vesting_curve_c,
      cliff
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
  * @notice Returns the current amount of tokens in the `self`.  
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
  * @notice Returns the current amount of total released tokens from the `self`.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun duration<T>(self: &Wallet<T>): u64 {
    self.duration
  }    

  public fun a<T>(self: &Wallet<T>): u64 {
    self.vesting_curve_a
  }

  public fun b<T>(self: &Wallet<T>): u64 {
    self.vesting_curve_b
  }  

  public fun c<T>(self: &Wallet<T>): u64 {
    self.vesting_curve_c
  }       

  public fun cliff<T>(self: &Wallet<T>): u64 {
    self.cliff
  }  
  
  /// From Movemate
  /// @dev Returns (1) the amount that has vested at the current time and the (2) portion of that amount that has not yet been released.
  public fun vesting_status<T>(self: &Wallet<T>, c: &Clock): u64 {
    let vested = quadratic_vested_amount(
      self.vesting_curve_a,
      self.vesting_curve_b,
      self.vesting_curve_c,
      self.start,
      self.cliff, 
      self.duration, 
      balance::value(&self.balance), 
      self.released, 
      clock::timestamp_ms(c)
    );

    vested - self.released
  }  

  // === Public Mutative Function ===        

  public fun claim<T>(self: &mut Wallet<T>, c: &Clock, ctx: &mut TxContext): Coin<T> {
    // Release amount
    let releasable = vesting_status(self, c);

    *&mut self.released = self.released + releasable;

    coin::from_balance(balance::split(&mut self.balance, releasable), ctx)
  }

  public fun destroy_zero<T>(self: Wallet<T>) {
    let Wallet { 
      id, 
      start: _, 
      duration: _, 
      balance, 
      released: _, 
      vesting_curve_a: _, 
      vesting_curve_b: _, 
      vesting_curve_c: _, 
      cliff: _
    } = self;
    object::delete(id);
    balance::destroy_zero(balance);
  }
}