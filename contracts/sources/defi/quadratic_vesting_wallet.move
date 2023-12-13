module suitears::quadratic_vesting_wallet {
  // === Imports ===

  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};

  use suitears::vesting::quadratic_vested_amount;

  // === Errors ===

  // @dev Thrown if you try to create a Wallet with a vesting schedule that starts in the past. 
  const EInvalidStart: u64 = 0;

  // === Struct ===

  struct Wallet<phantom T> has key, store {
    id: UID,
    // Amount of tokens to give to the holder of the wallet
    balance: Balance<T>,
    // Total amount of `Coin<T>` released so far. 
    released: u64,
    // a The a in ax^2 + bx + c.
    a: u64,
    // b The a in ax^2 + bx + c.
    b: u64,
    // c The a in ax^2 + bx + c.
    c: u64,
    // The holder can start claiming tokens after this date. 
    start: u64,
    // cliff Waiting period until the release of tokens start.
    cliff: u64,
    // The duration of the vesting. 
    duration: u64
  }

  // === Public Create Function ===  

  /*
  * @notice It creates a new {Wallet<T>}.  
  *
  * @param token A `sui::coin::Coin<T>`.
  * @param ck The shared object `sui::clock::Clock`  
  * @param a The a in ax^2 + bx + c. 
  * @param b The b in ax^2 + bx + c. 
  * @param c The c in ax^2 + bx + c.   
  * @param start Dictate when the vesting schedule starts.  
  * @param cliff Waiting period until the release of tokens start.   
  * @param duration The duration of the vesting schedule. 
  * @return Wallet<T>.
  *
  * aborts-if:   
  * - `start` is in the past.     
  */
  public fun new<T>(
    token: Coin<T>, 
    ck: &Clock, 
    a: u64,
    b: u64,
    c: u64,
    start: u64,
    cliff: u64,
    duration: u64,
    ctx: &mut TxContext
  ): Wallet<T> {
    assert!(start >= clock::timestamp_ms(ck), EInvalidStart);
    Wallet {
      id: object::new(ctx),
      balance: coin::into_balance(token),
      released: 0,
      start, 
      duration,
      a,
      b,
      c,
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

  /*
  * @notice Returns the a The a in ax^2 + bx + c.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun a<T>(self: &Wallet<T>): u64 {
    self.a
  }

  /*
  * @notice Returns the b The a in ax^2 + bx + c.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun b<T>(self: &Wallet<T>): u64 {
    self.b
  }  

  /*
  * @notice Returns the c The a in ax^2 + bx + c.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun c<T>(self: &Wallet<T>): u64 {
    self.c
  }       

  /*
  * @notice Returns the cliff period from the `self`.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun cliff<T>(self: &Wallet<T>): u64 {
    self.cliff
  }  
  
  /*
  * @notice Releases the current amount of coins available to the caller based on a quadratic schedule.  
  *
  * @param self A {Wallet<T>}.
  * @param c The `sui::clock::Clock` shared object. 
  * @return u64. A portion of the amount that can be claimed by the user. 
  */
  public fun vesting_status<T>(self: &Wallet<T>, c: &Clock): u64 {
    let vested = quadratic_vested_amount(
      self.a,
      self.b,
      self.c,
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

  /*
  * @notice Releases the current amount of coins available to the caller based on a quadratic schedule.  
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
    let Wallet { 
      id, 
      start: _, 
      duration: _, 
      balance, 
      released: _, 
      a: _, 
      b: _, 
      c: _, 
      cliff: _
    } = self;
    object::delete(id);
    balance::destroy_zero(balance);
  }
}