/*
* @title Linear Vesting Wallet
*
* @notice Creates a Wallet that allows the holder to claim coins linearly with clawback capability. 
*/
module suitears::linear_vesting_wallet_clawback {
  // === Imports ===

  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};

  use suitears::math64;
  use suitears::owner::{Self, OwnerCap};
  use suitears::vesting::linear_vested_amount;

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
    clawbacked: u64
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
  * @param c The shared object `sui::clock::Clock`
  * @param start Dictate when the vesting schedule starts.    
  * @param duration The duration of the vesting schedule. 
  * @return OwnerCap<ClawBackWitness>. The holder of this capability can claw back the coins. 
  * @return OwnerCap<RecipientWitness>. The holder of this capability can claim tokens according to the linear schedule.  
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
      clawbacked: 0
    };

    let clawback_cap = owner::new(ClawBackWitness {}, vector[object::id(&wallet)], ctx);
    let recipient_cap = owner::new(RecipientWitness {}, vector[object::id(&wallet)], ctx);

    (clawback_cap, recipient_cap, wallet)
  }

  /*
  * @notice It shares the {Wallet<T>} with the network.
  *
  * @param self A {Wallet<T>}.  
  */
  #[lint_allow(share_owned)]
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
  * @notice Returns the vesting schedule start time.  
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
  * @notice Returns the number of tokens that were claw-backed by the holder of {OwnerCap<ClawBackWitness>} from the `self`.  
  *
  * @param self A {Wallet<T>}.
  * @return u64. 
  */
  public fun clawbacked<T>(self: &Wallet<T>): u64 {
    self.clawbacked
  }  

  /*
  * @notice Returns the current amount of coins available to the caller based on the linear schedule.  
  *
  * @param self A {Wallet<T>}.
  * @param c The `sui::clock::Clock` shared object. 
  * @return u64. The amount that has vested at the current time. 
  * @return u64. A portion of the amount that has not yet been released
  */
  public fun vesting_status<T>(self: &Wallet<T>, c: &Clock): u64 {
    let vested = linear_vested_amount(
      self.start, 
      self.duration, 
      balance::value(&self.balance) + self.clawbacked, 
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
    let releasable = vesting_status(self, c);

    self.released = self.released + releasable;
    let current_balance = balance::value(&self.balance);

    coin::from_balance(balance::split(&mut self.balance, math64::min(releasable, current_balance)), ctx)
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
  public fun clawback<T>(self: &mut Wallet<T>, cap: OwnerCap<ClawBackWitness>, c: &Clock, ctx: &mut TxContext): Coin<T> {
    owner::assert_ownership(&cap, object::id(self));
    owner::destroy(cap);
    // Release amount
    let releasable = vesting_status(self, c);

    let remaining_value = balance::value(&self.balance) - releasable;

    self.clawbacked = remaining_value;

    coin::from_balance(balance::split(&mut self.balance, remaining_value), ctx)
  }  

  /*
  * @notice Destroys a {Wallet<T>} with no balance.  
  *
  * @param self A {Wallet<T>}.
  */
  public fun destroy_zero<T>(self: Wallet<T>) {
    let Wallet { id, start: _, duration: _, balance, released: _, clawbacked: _ } = self;
    object::delete(id);
    balance::destroy_zero(balance);
  }
}