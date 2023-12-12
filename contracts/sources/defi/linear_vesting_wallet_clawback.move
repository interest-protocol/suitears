/*
* @title Linear Vesting Wallet
*
* @notice Creates a Wallet that allows the holder to claim coins linearly with clawback capability. 
*/
module suitears::linear_vesting_wallet_with_clawback {
  // === Imports ===

  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};

  use suitears::owner::{Self, OwnerCap};

  // === Errors ===

  // @dev Thrown if you try to create a Wallet with a vesting schedule that starts in the past. 
  const EInvalidStart: u64 = 0;

  // Must be shared to allow both the clawback and recipient owners to interact with it.  
  struct Wallet<phantom T> has key {
    id: UID,
    // Amount of tokens to give to the holder of the wallet
    balance: Balance<T>,
    // Total amount of `Coin<T>` released so far. 
    released: u64,
    // The holder can start claiming tokens after this date.
    start: u64,
    // The duration of the vesting. 
    duration: u64,
  }

  // @dev The {OwnerCap<RecipientWitness>} with this witness can claim the coins over time. 
  struct RecipientWitness has drop {}

  // @dev The {OwnerCap<ClawBackWitness>} with this witness can clawback the all not releasable coins. 
  struct ClawBackWitness has drop {}

  // === Public Create Function ===  

  /*
  * @notice It creates a new {Wallet<T>} and two capabilities for the recipient and the clawback owner.  
  *
  * @param token A `sui::coin::Coin<T>`.
  * @param start Dictate when the vesting schedule starts.    
  * @param duration The duration of the vesting schedule. 
  * @return OwnerCap<ClawBackWitness>. The holder of this capability can clawback the coins. 
  * @return OwnerCap<RecipientWitness>. The holder of this capability can claim tokens according tgo the linear schedule.  
  * @return Wallet<T>.
  *
  * aborts-if:   
  * - `start` is in the past.     
  */
  public fun new<T>(
    token: Coin<T>, 
    c: &Clock, 
    start: u64, 
    duration: u64, 
    ctx: &mut TxContext
  ): (OwnerCap<ClawBackWitness>, OwnerCap<RecipientWitness>, Wallet<T>) {
    assert!(start >= clock::timestamp_ms(c), EInvalidStart);
    let wallet = Wallet {
      id: object::new(ctx),
      balance: coin::into_balance(token),
      released: 0,
      start, 
      duration,
    };

    let clawback_cap = owner::new(ClawBackWitness {}, vector[object::id(&wallet)], ctx);
    let recipient_cap = owner::new(RecipientWitness {}, vector[object::id(&wallet)], ctx);

    (clawback_cap, recipient_cap, wallet)
  }

  /*
  * @notice It shares the {Wallet<T>} with the network.
  * @param self A {Wallet<T>}.  
  */
  public fun share<T>(self: Wallet<T>) {
    transfer::share_object(self);
  }

  // === Public View Functions ===  

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

  // === Public Mutative Functions ===  

  /*
  * @notice Releases the current amount of coins available to the caller based on the linear schedule.  
  *
  * @param self A {Wallet<T>}.
  * @param cap The recipient capability that owns the `self`.  
  * @param c The `sui::clock::Clock` shared object. 
  * @return Coin<T>. 
  *
  * aborts-if:  
  * - `cap` does not own the `self`. 
  */
  public fun claim<T>(self: &mut Wallet<T>, cap: &OwnerCap<RecipientWitness>, c: &Clock, ctx: &mut TxContext): Coin<T> {
    owner::assert_ownership(cap, object::id(self));

    // Release amount
    let (_, releasable) = vesting_status(self, c);

    *&mut self.released = self.released + releasable;

    coin::from_balance(balance::split(&mut self.balance, releasable), ctx)
  }

  /*
  * @notice Returns all unreleased coins to the `cap` holder.  
  *
  * @param self A {Wallet<T>}.
  * @param cap The clawback capability that owns the `self`.  
  * @param c The `sui::clock::Clock` shared object. 
  * @return Coin<T>. 
  *
  * aborts-if:  
  * - `cap` does not own the `self`. 
  */
  public fun clawback<T>(self: &mut Wallet<T>, cap: &OwnerCap<ClawBackWitness>, c: &Clock, ctx: &mut TxContext): Coin<T> {
    owner::assert_ownership(cap, object::id(self));

    // Release amount
    let (_, releasable) = vesting_status(self, c);

    *&mut self.released = self.released + releasable;

    let remaining_value = balance::value(&self.balance) - releasable;

    coin::from_balance(balance::split(&mut self.balance, remaining_value), ctx)
  }  

  /*
  * @notice Releases the current amount of coins available to the caller based on the linear schedule.  
  *
  * @param self A {Wallet<T>}.
  * @param c The `sui::clock::Clock` shared object. 
  * @return u64. The amount that has vested at the current time. 
  * @return u64. A portion of the amount that has not yet been released
  */
  public fun vesting_status<T>(self: &Wallet<T>, c: &Clock): (u64, u64) {
    let vested = vested_amount(
      self.start, 
      self.duration, 
      balance::value(&self.balance), 
      self.released, 
      clock::timestamp_ms(c)
    );

    (vested, vested - self.released)
  }

  /*
  * @notice Destroys a {Wallet<T>} with no balance.  
  *
  * @param self A {Wallet<T>}.
  */
  public fun destroy_zero<T>(self: Wallet<T>) {
    let Wallet { id, start: _, duration: _, balance, released: _ } = self;
    object::delete(id);
    balance::destroy_zero(balance);
  }

  // === Private Functions ===    

  /*
  * @notice Calculates the amount that has already vested.  
  *
  * @param start The beginning of the vesting schedule.  
  * @param duration The duration of the schedule.  
  * @param balance The current amount of tokens in the wallet.   
  * @param already_released The total amount of tokens released.  
  * @param timestamp The current time in milliseconds.  
  * @return u64. The vested amount.  
  */
  fun vested_amount(start: u64, duration: u64, balance: u64, already_released: u64, timestamp: u64): u64 {
    vesting_schedule(start, duration, balance + already_released, timestamp)
  }
  
  /*
  * @notice Virtual implementation of the vesting formula.  
  *
  * @param start The beginning of the vesting schedule.  
  * @param duration The duration of the schedule.  
  * @param total_allocation The total amount of tokens since the beginning.  
  * @param timestamp The current time in milliseconds.  
  * @return u64. This returns the amount vested, as a function of time, for an asset given its total historical allocation.  
  */ 
  fun vesting_schedule(start: u64, duration: u64, total_allocation: u64, timestamp: u64): u64 {
    if (timestamp < start) return 0;
    if (timestamp > start + duration) return total_allocation;
    (total_allocation * (timestamp - start)) / duration
  }
}