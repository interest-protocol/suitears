module suitears::airdrop {
  use std::vector;

  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID}; 
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};

  use suitears::airdrop_utils::verify;
  use suitears::bitmap::{Self, Bitmap};

  const EAlreadyClaimed: u64 = 0;
  const EInvalidRoot: u64 = 1;
  const EInvalidStartTime: u64 = 2;

  struct Airdrop<phantom T> has key, store { 
    id: UID,
    balance: Balance<T>,
    root: vector<u8>,
    start: u64,
    map: Bitmap
  }

  public fun new<T>(airdrop_coin: Coin<T>, root: vector<u8>, start: u64, ctx: &mut TxContext): Airdrop<T> {
    assert!(!vector::is_empty(&root), EInvalidRoot);
    Airdrop {
        id: object::new(ctx),
        balance: coin::into_balance(airdrop_coin),
        root,
        start,
        map: bitmap::new(ctx)
    }
  }

  public fun balance<T>(self: &Airdrop<T>): u64 {
    balance::value(&self.balance)
  }

  public fun root<T>(self: &Airdrop<T>): vector<u8> {
    self.root
  }

  public fun start<T>(self: &Airdrop<T>): u64 {
    self.start
  }

  public fun borrow_map<T>(self: &Airdrop<T>): &Bitmap {
    &self.map
  }

  public fun deposit<T>(self: &mut Airdrop<T>, airdrop_coin: Coin<T>): u64 {
    balance::join(&mut self.balance, coin::into_balance(airdrop_coin))
  }

  public fun get_airdrop<T>(
    self: &mut Airdrop<T>, 
    c: &Clock,
    proof: vector<vector<u8>>, 
    amount: u64, 
    ctx: &mut TxContext
  ): Coin<T> {
    assert!(self.start > clock::timestamp_ms(c), EInvalidStartTime);
    let index = verify(self.root, proof, amount, ctx);

    assert!(!bitmap::get(&self.map, index), EAlreadyClaimed);

    bitmap::set(&mut self.map, index);

    coin::take(&mut self.balance, amount, ctx)
  }

  public fun has_account_claimed<T>(
    self: &Airdrop<T>,
    proof: vector<vector<u8>>, 
    amount: u64, 
    ctx: &mut TxContext
  ): bool {
    bitmap::get(&self.map, verify(self.root, proof, amount, ctx))
  }

  public fun destroy_zero<T>(self: Airdrop<T>) {
    let Airdrop {id, balance, start: _, root: _, map} = self;
    object::delete(id);
    balance::destroy_zero(balance);
    bitmap::destroy(map);
  }
}