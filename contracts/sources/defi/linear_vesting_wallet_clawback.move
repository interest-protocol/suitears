module suitears::linear_vesting_wallet_with_clawback {
  
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};

  use suitears::owner::{Self, OwnerCap};

  const EInvalidStart: u64 = 0;

  struct Wallet<phantom T> has key {
    id: UID,
    balance: Balance<T>,
    released: u64,
    start: u64,
    duration: u64,
  }

  struct RecipientWitness has drop {}

  struct ClawBackWitness has drop {}

  public fun balance<T>(self: &Wallet<T>): u64 {
    balance::value(&self.balance)
  }

  public fun start<T>(self: &Wallet<T>): u64 {
    self.start
  }  

  public fun released<T>(self: &Wallet<T>): u64 {
    self.released
  }

  public fun duration<T>(self: &Wallet<T>): u64 {
    self.duration
  }    

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

  public fun share<T>(self: Wallet<T>) {
    transfer::share_object(self);
  }

  public fun claim<T>(self: &mut Wallet<T>, cap: &OwnerCap<RecipientWitness>, c: &Clock, ctx: &mut TxContext): Coin<T> {
    owner::assert_ownership(cap, object::id(self));

    // Release amount
    let (_, releasable) = vesting_status(self, c);

    *&mut self.released = self.released + releasable;

    coin::from_balance(balance::split(&mut self.balance, releasable), ctx)
  }

  public fun clawback<T>(self: &mut Wallet<T>, cap: &OwnerCap<ClawBackWitness>, c: &Clock, ctx: &mut TxContext): Coin<T> {
    owner::assert_ownership(cap, object::id(self));

    // Release amount
    let (_, releasable) = vesting_status(self, c);

    *&mut self.released = self.released + releasable;

    let remaining_value = balance::value(&self.balance) - releasable;

    coin::from_balance(balance::split(&mut self.balance, remaining_value), ctx)
  }  

  /// From Movemate
  /// @dev Returns (1) the amount that has vested at the current time and the (2) portion of that amount that has not yet been released.
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

  public fun destroy_zero<T>(self: Wallet<T>) {
    let Wallet { id, start: _, duration: _, balance, released: _ } = self;
    object::delete(id);
    balance::destroy_zero(balance);
  }

    /// From Movemate
    /// Calculates the amount that has already vested. Default implementation is a linear vesting curve.
  fun vested_amount(start: u64, duration: u64, balance: u64, already_released: u64, timestamp: u64): u64 {
    vesting_schedule(start, duration, balance + already_released, timestamp)
  }

    /// From Movemate
    /// @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for an asset given its total historical allocation.
  fun vesting_schedule(start: u64, duration: u64, total_allocation: u64, timestamp: u64): u64 {
    if (timestamp < start) return 0;
    if (timestamp > start + duration) return total_allocation;
    (total_allocation * (timestamp - start)) / duration
  }
}