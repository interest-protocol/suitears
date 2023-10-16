module suitears::linear_vesting_airdrop {
  use std::vector;
  use std::hash;
  
  use sui::bcs;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::balance::{Self, Balance}; 
  use sui::tx_context::{Self, TxContext};

  use suitears::bitmap::{Self, Bitmap};
  use suitears::ens_merkle_proof as merkle_proof;
  use suitears::linear_vesting_wallet::{Self as wallet, Wallet}; 

  const EInvalidProof: u64 = 0;
  const EAlreadyClaimed: u64 = 1;
  const EInvalidRoot: u64 = 2;
  const EInvalidStartTime: u64 = 4;

  struct AirdropStorage<phantom T> has key, store { 
    id: UID,
    balance: Balance<T>,
    root: vector<u8>,
    start: u64,
    duration: u64,
    map: Bitmap
  }

  public fun create<T>(c: &Clock, airdrop_coin: Coin<T>, root: vector<u8>, start: u64, duration: u64, ctx: &mut TxContext): AirdropStorage<T> {
    assert!(!vector::is_empty(&root), EInvalidRoot);
    assert!(start > clock::timestamp_ms(c), EInvalidStartTime);
    AirdropStorage {
        id: object::new(ctx),
        balance: coin::into_balance(airdrop_coin),
        root,
        start,
        duration,
        map: bitmap::new(ctx)
    }
  }

  public fun deposit<T>(storage: &mut AirdropStorage<T>, airdrop_coin: Coin<T>): u64 {
    balance::join(&mut storage.balance, coin::into_balance(airdrop_coin))
  }  

  public fun get_airdrop<T>(
    storage: &mut AirdropStorage<T>, 
    clock_object: &Clock,
    proof: vector<vector<u8>>, 
    amount: u64, 
    ctx: &mut TxContext
  ): Wallet<T> {
    let sender = tx_context::sender(ctx);
    let payload = bcs::to_bytes(&sender);

    vector::append(&mut payload, bcs::to_bytes(&amount));

    let leaf = hash::sha3_256(payload);

    let (pred, index) = merkle_proof::verify(&proof, storage.root, leaf);
    
    assert!(pred, EInvalidProof);

    assert!(!has_account_claimed(storage, index), EAlreadyClaimed);

    bitmap::set(&mut storage.map, index);

    wallet::create(
      coin::take(&mut storage.balance, amount, ctx),
      clock_object,
      storage.start,
      storage.duration,
      ctx
    )
  }

  public fun has_account_claimed<T>(storage: &AirdropStorage<T>, index: u256): bool {
    bitmap::get(&storage.map, index)
  }

  public fun destroy_zero<T>(storage: AirdropStorage<T>) {
    let AirdropStorage {id, balance, start: _, root: _, duration: _, map} = storage;
    object::delete(id);
    balance::destroy_zero(balance);
    bitmap::destroy(map);
  }

  #[test_only]
  public fun read_storage<T>(storage: &AirdropStorage<T>): (u64, vector<u8>, u64) {
    (balance::value(&storage.balance), storage.root, storage.start)
  }
}