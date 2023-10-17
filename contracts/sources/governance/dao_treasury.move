module suitears::dao_treasury { 
  use std::type_name::{TypeName, get};

  use sui::event::emit;
  use sui::clock::Clock;
  use sui::bag::{Self, Bag};
  use sui::package::Publisher;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::tx_context::{Self, TxContext};

  use suitears::dao_action::{Action, finish_action};
  use suitears::linear_vesting_wallet::{Self, Wallet as LinearWallet};
  use suitears::quadratic_vesting_wallet::{Self, Wallet as QuadraticWallet};

  friend suitears::dao;

  const EMismatchCoinType: u64 = 0;
  const EInvalidPublisher: u64 = 1;

  struct TransferWitness has drop {}

  struct TransferPayload has key, store {
    id: UID,
    type: TypeName,
    value: u64,
    publisher_id: ID
  }

  struct TransferVestingWalletPayload has key, store {
    id: UID,
    start: u64,
    duration: u64,
    type: TypeName,
    value: u64,
    publisher_id: ID
  }

  struct TransferQuadraticWalletPayload has key, store {
    id: UID,
    vesting_curve_a: u64,
    vesting_curve_b: u64,
    vesting_curve_c: u64,
    start: u64,
    cliff: u64,
    duration: u64,
    type: TypeName,
    value: u64,
    publisher_id: ID
  }

  struct DaoTreasury<phantom DaoWitness> has key, store {
    id: UID,
    coins: Bag,
    dao: ID
  }

  // Events

  struct CreateDaoTreasury<phantom DaoWitness> has copy, drop {
    treasury_id: ID,
    dao_id: ID
  }

  struct Donate<phantom DaoWitness, phantom CoinType> has copy, drop {
    value: u64,
    donator: address  
  }

  struct Transfer<phantom DaoWitness, phantom CoinType> has copy, drop {
    value: u64,
    publisher_id: ID,
    sender: address
  }
  
  struct TransferLinearWallet<phantom DaoWitness, phantom CoinType> has copy, drop {
    value: u64,
    publisher_id: ID,
    sender: address,
    wallet_id: ID,
    start: u64,
    duration: u64
  }

  struct TransferQuadraticWallet<phantom DaoWitness, phantom CoinType> has copy, drop {
    value: u64,
    publisher_id: ID,
    sender: address,
    wallet_id: ID,
    start: u64,
    duration: u64,
    cliff: u64,
    vesting_curve_a: u64,
    vesting_curve_b: u64,
    vesting_curve_c: u64,
  }

  public(friend) fun create<DaoWitness: drop>(dao: ID, ctx: &mut TxContext): DaoTreasury<DaoWitness> {
    let treasury = DaoTreasury {
      id: object::new(ctx),
      coins: bag::new(ctx),
      dao
    };

    emit(CreateDaoTreasury<DaoWitness> { treasury_id: object::id(&treasury), dao_id: dao });

    treasury
  }

  public fun donate<DaoWitness: drop, CoinType>(treasury: &mut DaoTreasury<DaoWitness>, token: Coin<CoinType>, ctx: &mut TxContext) {
    emit(Donate<DaoWitness, CoinType> { value: coin::value(&token), donator: tx_context::sender(ctx) });
    balance::join(bag::borrow_mut<TypeName, Balance<CoinType>>(&mut treasury.coins, get<CoinType>()), coin::into_balance(token));
  }

  public fun view<DaoWitness: drop, CoinType>(treasury: &DaoTreasury<DaoWitness>): u64 {
    balance::value(bag::borrow<TypeName, Balance<CoinType>>(&treasury.coins, get<CoinType>()))
  }

  public fun transfer<DaoWitness: drop, CoinType>(
    treasury: &mut DaoTreasury<DaoWitness>,
    pub: &Publisher,
    action: Action<DaoWitness, TransferWitness, CoinType, TransferPayload>, 
    ctx: &mut TxContext
  ): Coin<CoinType> {
    let payload = finish_action(TransferWitness {}, action);
    assert!(get<CoinType>() == payload.type, EMismatchCoinType);
    assert!(object::id(pub) == payload.publisher_id, EInvalidPublisher);
    
    let token = coin::take(bag::borrow_mut(&mut treasury.coins, payload.type), payload.value, ctx);

    emit(Transfer<DaoWitness, CoinType> { 
        value: payload.value, 
        publisher_id: payload.publisher_id, 
        sender: tx_context::sender(ctx) 
      }
    );

    destroy_transfer_payload(payload);
    token
  }

  public fun transfer_linear_vesting_wallet<DaoWitness: drop, CoinType>(
    treasury: &mut DaoTreasury<DaoWitness>,
    c: &Clock,
    pub: &Publisher,
    action: Action<DaoWitness, TransferWitness, CoinType, TransferVestingWalletPayload>, 
    ctx: &mut TxContext    
  ): LinearWallet<CoinType> {
    let payload = finish_action(TransferWitness {}, action);
    assert!(get<CoinType>() == payload.type, EMismatchCoinType);
    assert!(object::id(pub) == payload.publisher_id, EInvalidPublisher);
    
    let token = coin::take<CoinType>(bag::borrow_mut(&mut treasury.coins, payload.type), payload.value, ctx);

    let wallet = linear_vesting_wallet::create(token, c, payload.start, payload.duration, ctx);

    emit(TransferLinearWallet<DaoWitness, CoinType> { 
        value: payload.value, 
        publisher_id: payload.publisher_id, 
        sender: tx_context::sender(ctx), 
        duration: payload.duration, 
        start: payload.start, 
        wallet_id: object::id(&wallet) 
      }
    );

    destroy_transfer_linear_vesting_wallet_payload(payload);
    
    wallet
  }

  public fun transfer_quadratic_vesting_wallett<DaoWitness: drop, CoinType>(
    treasury: &mut DaoTreasury<DaoWitness>,
    c: &Clock,
    pub: &Publisher,
    action: Action<DaoWitness, TransferWitness, CoinType, TransferQuadraticWalletPayload>, 
    ctx: &mut TxContext    
  ): QuadraticWallet<CoinType> {
    let payload = finish_action(TransferWitness {}, action);
    assert!(get<CoinType>() == payload.type, EMismatchCoinType);
    assert!(object::id(pub) == payload.publisher_id, EInvalidPublisher);
    
    let token = coin::take<CoinType>(bag::borrow_mut(&mut treasury.coins, payload.type), payload.value, ctx);

    let wallet = quadratic_vesting_wallet::create(
      token, 
      c,
      payload.vesting_curve_a,
      payload.vesting_curve_b,
      payload.vesting_curve_c,
      payload.start,
      payload.cliff,
      payload.duration, 
      ctx
    );

    emit(TransferQuadraticWallet<DaoWitness, CoinType> {
        value: payload.value, 
        publisher_id: payload.publisher_id, 
        sender: tx_context::sender(ctx), 
        duration: payload.duration, 
        start: payload.start, 
        wallet_id: object::id(&wallet), 
        vesting_curve_a: payload.vesting_curve_a, 
        vesting_curve_b: payload.vesting_curve_b, 
        vesting_curve_c: payload.vesting_curve_c, 
        cliff: payload.cliff 
      }
    );

    destroy_transfer_quadratic_vesting_wallet_payload(payload);
    
    wallet
  }

  public fun view_transfer_payload(payload: &TransferPayload): (ID, TypeName, u64, ID) {
    (object::id(payload), payload.type, payload.value, payload.publisher_id)
  }

  public fun create_transfer_payload<CoinType>(value: u64, publisher_id: ID, ctx: &mut TxContext): TransferPayload {
    TransferPayload {
      id: object::new(ctx),
      type: get<CoinType>(),
      value,
      publisher_id
    }
  }

  public fun destroy_transfer_payload(payload: TransferPayload) {
    let TransferPayload { id, type: _, value: _, publisher_id: _} = payload;
    object::delete(id);
  }

  public fun view_transfer_linear_vesting_wallet_payload(payload: &TransferVestingWalletPayload): (ID, TypeName, u64, ID, u64, u64) {
    (object::id(payload), payload.type, payload.value, payload.publisher_id, payload.start, payload.duration)
  }

  public fun create_transfer_linear_vesting_wallet_payload<CoinType>(
    value: u64, 
    publisher_id: ID,
    start: u64, 
    duration: u64,
    ctx: &mut TxContext
  ): TransferVestingWalletPayload {
    TransferVestingWalletPayload {
      id: object::new(ctx),
      type: get<CoinType>(),
      value,
      publisher_id,
      start,
      duration
    }
  }

  public fun destroy_transfer_linear_vesting_wallet_payload(payload: TransferVestingWalletPayload) {
    let TransferVestingWalletPayload { id, type: _, value: _, publisher_id: _, start: _, duration: _} = payload;
    object::delete(id);
  }

  public fun view_transfer_quadratic_vesting_wallet_payload(payload: &TransferQuadraticWalletPayload): (ID, TypeName, u64, ID, u64, u64, u64, u64, u64, u64) {
    (
      object::id(payload), 
      payload.type, 
      payload.value, 
      payload.publisher_id, 
      payload.cliff,
      payload.start, 
      payload.vesting_curve_a, 
      payload.vesting_curve_b, 
      payload.vesting_curve_c, 
      payload.duration
      )
  }

  public fun create_transfer_quadratic_vesting_wallet_payload<CoinType>(
    value: u64, 
    publisher_id: ID,
    cliff: u64, 
    start: u64,
    vesting_curve_a: u64,
    vesting_curve_b: u64,
    vesting_curve_c: u64,
    duration: u64,
    ctx: &mut TxContext
  ): TransferQuadraticWalletPayload {
    TransferQuadraticWalletPayload {
      id: object::new(ctx),
      type: get<CoinType>(),
      value,
      publisher_id,
      cliff,
      start,
      duration,
      vesting_curve_a,
      vesting_curve_b,
      vesting_curve_c
    }
  }

  public fun destroy_transfer_quadratic_vesting_wallet_payload(payload: TransferQuadraticWalletPayload) {
    let TransferQuadraticWalletPayload { 
      id, 
      type: _, 
      value: _, 
      publisher_id: _, 
      cliff: _,
      start: _, 
      duration: _,
      vesting_curve_a: _,
      vesting_curve_b: _,
      vesting_curve_c: _ 
    } = payload;
    object::delete(id);
  }
}
