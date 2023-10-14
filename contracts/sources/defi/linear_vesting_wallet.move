module suitears::linear_vesting_wallet {
  
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  use suitears::ownership::{Self, OwnershipCap};

  const EInvalidStart: u64 = 0;

  struct Wallet<phantom T> has key, store {
    id: UID,
    token: Coin<T>,
    released: u64,
    start: u64,
    duration: u64,
    has_clawback: bool,
    recipient: address
  }

  struct WalletWitness has drop {}

  struct WalletClawbackCap has key, store {
    id: UID,
    cap: OwnershipCap<WalletWitness>
  }

  public fun create<T>(token: Coin<T>, c: &Clock, start: u64, duration: u64, ctx: &mut TxContext): Wallet<T> {
    assert!(start >= clock::timestamp_ms(c), EInvalidStart);
    Wallet {
      id: object::new(ctx),
      token,
      released: 0,
      start, 
      duration,
      has_clawback: false,
      recipient: @0x0 // wallet without clawback can be claimed by whoever holds the object
    }
  }

  public fun create_with_new_clawback<T>(
    token: Coin<T>, 
    c: &Clock, 
    start: u64, 
    duration: u64, 
    recipient: address,
    ctx: &mut TxContext
  ): WalletClawbackCap {
    assert!(start >= clock::timestamp_ms(c), EInvalidStart);
    let wallet = Wallet {
      id: object::new(ctx),
      token,
      released: 0,
      start, 
      duration,
      has_clawback: true,
      recipient
    };

    let cap = WalletClawbackCap {
      id: object::new(ctx),
      cap: ownership::create(WalletWitness {}, vector[object::id(&wallet)], ctx)
    };

    transfer::share_object(wallet);

    cap
  }

  public fun create_with_clawback<T>(
    cap: &mut WalletClawbackCap,
    token: Coin<T>, 
    c: &Clock, 
    start: u64, 
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
      has_clawback: true,
      recipient
    };

    ownership::add(WalletWitness {},&mut cap.cap, object::id(&wallet));

    transfer::share_object(wallet);
  }

  public fun read<T>(self: &Wallet<T>): (u64, u64, u64, u64, bool, address) {
    (coin::value(&self.token), self.released, self.start, self.duration, self.has_clawback, self.recipient)
  }

  public fun release<T>(c: &Clock, wallet: &mut Wallet<T>, ctx: &mut TxContext): Coin<T> {
    // Release amount
    let releasable = vested_amount(wallet.start, wallet.duration, coin::value(&wallet.token), wallet.released, clock::timestamp_ms(c)) - wallet.released;

    *&mut wallet.released = *&wallet.released + releasable;

    coin::split(&mut wallet.token, releasable, ctx)
  }

  public fun clawback<T>(cap: &WalletClawbackCap, c: &Clock, wallet: &mut Wallet<T>, ctx: &mut TxContext): Coin<T> {
    ownership::assert_ownership(&cap.cap, object::id(wallet));

    transfer::public_transfer(release(c, wallet, ctx), wallet.recipient);

    let remaining_value = coin::value(&wallet.token);

    coin::split(&mut wallet.token, remaining_value, ctx)
  }

  /// From Movemate
  /// @dev Returns (1) the amount that has vested at the current time and the (2) portion of that amount that has not yet been released.
  public fun vesting_status<T>(wallet: &Wallet<T>, c: &Clock): (u64, u64) {
    let vested = vested_amount(
      wallet.start, 
      wallet.duration, 
      coin::value(&wallet.token), 
      wallet.released, 
      clock::timestamp_ms(c)
    );

    (vested, vested - wallet.released)
  }

  public fun destroy_cap(cap: WalletClawbackCap) {
    let WalletClawbackCap { id, cap } = cap;
    object::delete(id);
    ownership::destroy(cap);
  }

  public fun destroy_wallet<T>(self: Wallet<T>) {
    let Wallet { id, start: _, duration: _, token, released: _, has_clawback: _, recipient: _} = self;
    object::delete(id);
    coin::destroy_zero(token);
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