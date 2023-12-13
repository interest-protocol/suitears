module suitears::quadratic_vesting_wallet_clawback {
  
  use sui::math;
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;

  
  use suitears::owner::{Self, OwnerCap};
  use suitears::fixed_point_roll::mul_down;

  const ROLL: u64 = 1_000_000_000; // 1e9

  const EInvalidStart: u64 = 0;

  struct Wallet<phantom T> has key, store {
    id: UID,
    token: Coin<T>,
    released: u64,
    vesting_curve_a: u64,
    vesting_curve_b: u64,
    vesting_curve_c: u64,
    start: u64,
    cliff: u64,
    duration: u64,
    has_clawback: bool,
    recipient: address
  }

  struct WalletWitness has drop {}

  public fun create<T>(
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
      token,
      released: 0,
      start, 
      duration,
      vesting_curve_a,
      vesting_curve_b,
      vesting_curve_c,
      cliff,
      has_clawback: false,
      recipient: @0x0 // wallet without clawback can be claimed by whoever holds the object
    }
  }

  public fun create_clawback_cap(ctx: &mut TxContext): OwnerCap<WalletWitness> {
    owner::new(WalletWitness {}, vector[], ctx)
  }

  public fun create_with_clawback<T>(
    cap: &mut OwnerCap<WalletWitness>,
    token: Coin<T>, 
    c: &Clock, 
    vesting_curve_a: u64,
    vesting_curve_b: u64,
    vesting_curve_c: u64,
    start: u64,
    cliff: u64,
    duration: u64,
    recipient: address,
    ctx: &mut TxContext
  ) {
    assert!(start >= clock::timestamp_ms(c), EInvalidStart);
    let wallet = Wallet {
      id: object::new(ctx),
      token,
      released: 0,
      start, 
      duration,
      vesting_curve_a,
      vesting_curve_b,
      vesting_curve_c,
      cliff,
      has_clawback: true,
      recipient
    };

    owner::add(cap, WalletWitness {},  object::id(&wallet));

    transfer::share_object(wallet);
  }

  public fun read<T>(self: &Wallet<T>): (u64, u64, u64, u64, u64, u64, u64, u64, bool, address) {
    (
      coin::value(&self.token), 
      self.released, 
      self.start, 
      self.duration,
      self.vesting_curve_a,
      self.vesting_curve_b,
      self.vesting_curve_c,
      self.cliff, 
      self.has_clawback, 
      self.recipient
    )
  }

  public fun release<T>(c: &Clock, wallet: &mut Wallet<T>, ctx: &mut TxContext): Coin<T> {
    // Release amount
    let (_, releasable) = vesting_status(c, wallet);

    *&mut wallet.released = *&wallet.released + releasable;

    coin::split(&mut wallet.token, releasable, ctx)
  }

  public fun clawback<T>(cap: &OwnerCap<WalletWitness>, c: &Clock, wallet: &mut Wallet<T>, ctx: &mut TxContext): Coin<T> {
    owner::assert_ownership(cap, object::id(wallet));

    transfer::public_transfer(release(c, wallet, ctx), wallet.recipient);

    let remaining_value = coin::value(&wallet.token);

    coin::split(&mut wallet.token, remaining_value, ctx)
  }

  /// From Movemate
  /// @dev Returns (1) the amount that has vested at the current time and the (2) portion of that amount that has not yet been released.
  public fun vesting_status<T>(c: &Clock, wallet: &Wallet<T>): (u64, u64) {
    let vested = vested_amount(
      wallet.vesting_curve_a,
      wallet.vesting_curve_b,
      wallet.vesting_curve_c,
      wallet.start,
      wallet.cliff, 
      wallet.duration, 
      coin::value(&wallet.token), 
      wallet.released, 
      clock::timestamp_ms(c)
    );

    (vested, vested - wallet.released)
  }

  public fun destroy_wallet<T>(cap: &OwnerCap<WalletWitness>,self: Wallet<T>) {
    owner::assert_ownership(cap, object::id(&self));
    let Wallet { id, start: _, duration: _, token, released: _, has_clawback: _, recipient: _, vesting_curve_a: _, vesting_curve_b: _, vesting_curve_c: _, cliff: _} = self;
    object::delete(id);
    coin::destroy_zero(token);
  }

    /// @dev Calculates the amount that has already vested. Default implementation is a linear vesting curve.
    fun vested_amount(a: u64, b: u64, c: u64, start: u64, cliff: u64, duration: u64, balance: u64, already_released: u64, timestamp: u64): u64 {
        vesting_schedule(a, b, c, start, cliff, duration, balance + already_released, timestamp)
    }

    /// @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for an asset given its total historical allocation.
    fun vesting_schedule(a: u64, b: u64, c: u64, start: u64, cliff: u64, duration: u64, total_allocation: u64, timestamp: u64): u64 {
        // Get time delta, check domain, and convert to proportion out of SCALAR
        let time_delta = timestamp - start;
        if (time_delta < cliff) return 0;
        if (time_delta >= duration) return total_allocation;
        let progress = time_delta * ROLL / duration;

        // Evaluate quadratic trinomial where y = vested proportion of total_allocation out of SCALAR and x = progress through vesting period out of SCALAR
        // No need to check for overflow when casting uint256 to int256 because `progress` maxes out at SCALAR and so does `(progress ** 2) / SCALAR`
        let vested_proportion = quadratic(progress, a, b, c);

        // Keep vested total_allocation in range [0, total]
        if (vested_proportion <= 0) return 0;
        if (vested_proportion >= ROLL) return total_allocation;

        // Releasable = total_allocation * vested proportion (divided by SCALAR since proportion is scaled by SCALAR)
        total_allocation * vested_proportion / ROLL
    }

    fun quadratic(x: u64, a: u64, b: u64, c: u64): u64 {
      mul_down(math::pow(x, 2) / ROLL, a + mul_down(b, x) + c)
    }
}