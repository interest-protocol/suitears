module suitears::airdrop {
  use std::vector;
  use std::hash;
  
  use sui::bcs;
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID}; 
  use sui::clock::{Self, Clock};
  use sui::table::{Self, Table};
  use sui::balance::Balance;
  use sui::tx_context::{Self, TxContext};

  #[test_only]
  use sui::balance;

  use suitears::merkle_proof;

  const EInvalidProof: u64 = 0;
  const EAlreadyClaimed: u64 = 1;
  const ETooEarly: u64 = 2;
  const EInvalidRoot: u64 = 3;

  struct AirdropStorage<phantom T> has key { 
    id: UID,
    balance: Balance<T>,
    root: vector<u8>,
    start: u64,
    accounts: Table<address, bool>
  }

  public fun create<T>(airdrop_coin: Coin<T>, root: vector<u8>, start: u64, ctx: &mut TxContext) {
    assert!(!vector::is_empty(&root), EInvalidRoot);
    transfer::share_object(AirdropStorage {
        id: object::new(ctx),
        balance: coin::into_balance(airdrop_coin),
        root,
        start,
        accounts: table::new(ctx)
    });
  }

  public fun get_airdrop<T>(
    storage: &mut AirdropStorage<T>, 
    clock_object: &Clock,
    proof: vector<vector<u8>>, 
    amount: u64, 
    ctx: &mut TxContext
  ): Coin<T> {
    assert!(storage.start >= clock::timestamp_ms(clock_object), ETooEarly);

    let sender = tx_context::sender(ctx);
    let payload = bcs::to_bytes(&sender);

    vector::append(&mut payload, bcs::to_bytes(&amount));

    let leaf = hash::sha3_256(payload);
    
    assert!(merkle_proof::verify(&proof, storage.root, leaf), EInvalidProof);

    assert!(!has_account_claimed(storage, sender), EAlreadyClaimed);

    coin::take(&mut storage.balance, amount, ctx)
  }

  public fun has_account_claimed<T>(storage: &AirdropStorage<T>, user: address): bool {
    table::contains(&storage.accounts, user)
  }

  #[test_only]
  public fun read_storage<T>(storage: &AirdropStorage<T>): (u64, vector<u8>, u64) {
    (balance::value(&storage.balance), storage.root, storage.start)
  }
}