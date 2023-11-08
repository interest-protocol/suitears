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

  use suitears::fixed_point_roll::roll_mul_up;
  use suitears::dao_action::{Action, finish_action, complete_rule};
  use suitears::linear_vesting_wallet::{Self, Wallet as LinearWallet};
  use suitears::quadratic_vesting_wallet::{Self, Wallet as QuadraticWallet};

  friend suitears::dao;

  const FLASH_LOAN_FEE: u128 = 5000000; // 0.5%

  const EMismatchCoinType: u64 = 0;
  const EInvalidPublisher: u64 = 1;
  const EFlashloanNotAllowed: u64 = 2;
  const ERepayAmountTooLow: u64 = 3;

  struct TreasuryActionWitness has drop {}

  struct TransferPayload has store, drop, copy {
    type: TypeName,
    value: u64,
    publisher_id: ID
  }

  struct TransferVestingWalletPayload has store, drop, copy {
    start: u64,
    duration: u64,
    type: TypeName,
    value: u64,
    publisher_id: ID
  }

  struct TransferQuadraticWalletPayload has store, drop, copy {
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

  struct DaoTreasury<phantom DaoWitness: drop> has key, store {
    id: UID,
    coins: Bag,
    dao: ID,
    allow_flashloan: bool
  }

  // * IMPORTANT do not add abilities 
  struct FlashLoan<phantom DaoWitness, phantom CoinType> {
    initial_balance: u64,
    fee: u64,
    type: TypeName
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

  struct FlashLoanRequest<phantom DaoWitness, phantom CoinType> has copy, drop {
    borrower: address,
    treasury_id: ID,
    value: u64,
    type: TypeName
  } 

  public(friend) fun create<DaoWitness: drop>(dao: ID, allow_flashloan: bool, ctx: &mut TxContext): DaoTreasury<DaoWitness> {
    let treasury = DaoTreasury {
      id: object::new(ctx),
      coins: bag::new(ctx),
      dao,
      allow_flashloan
    };

    emit(CreateDaoTreasury<DaoWitness> { treasury_id: object::id(&treasury), dao_id: dao });

    treasury
  }

  public fun donate<DaoWitness: drop, CoinType>(treasury: &mut DaoTreasury<DaoWitness>, token: Coin<CoinType>, ctx: &mut TxContext) {
    emit(Donate<DaoWitness, CoinType> { value: coin::value(&token), donator: tx_context::sender(ctx) });

    let key = get<CoinType>();

    if (!bag::contains(&treasury.coins, key))
      bag::add(&mut treasury.coins, key, coin::into_balance(token))
    else 
      {
        balance::join(bag::borrow_mut<TypeName, Balance<CoinType>>(&mut treasury.coins, key), coin::into_balance(token));
      }
  }

  public fun view<DaoWitness: drop, CoinType>(treasury: &DaoTreasury<DaoWitness>): u64 {
    balance::value(bag::borrow<TypeName, Balance<CoinType>>(&treasury.coins, get<CoinType>()))
  }

  public fun transfer<DaoWitness: drop, CoinType>(
    treasury: &mut DaoTreasury<DaoWitness>,
    pub: &Publisher,
    action: Action<DaoWitness, CoinType, TransferPayload>, 
    ctx: &mut TxContext
  ): Coin<CoinType> {
    complete_rule(TreasuryActionWitness {}, &mut action);
    let payload = finish_action(action);
    assert!(get<CoinType>() == payload.type, EMismatchCoinType);
    assert!(object::id(pub) == payload.publisher_id, EInvalidPublisher);
    
    let token = coin::take(bag::borrow_mut(&mut treasury.coins, payload.type), payload.value, ctx);

    emit(Transfer<DaoWitness, CoinType> { 
        value: payload.value, 
        publisher_id: payload.publisher_id, 
        sender: tx_context::sender(ctx) 
      }
    );

    token
  }

  public fun transfer_linear_vesting_wallet<DaoWitness: drop, CoinType>(
    treasury: &mut DaoTreasury<DaoWitness>,
    c: &Clock,
    pub: &Publisher,
    action: Action<DaoWitness, CoinType, TransferVestingWalletPayload>, 
    ctx: &mut TxContext    
  ): LinearWallet<CoinType> {
    complete_rule(TreasuryActionWitness {}, &mut action);
    let payload = finish_action( action);
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
    
    wallet
  }

  public fun transfer_quadratic_vesting_wallet<DaoWitness: drop, CoinType>(
    treasury: &mut DaoTreasury<DaoWitness>,
    c: &Clock,
    pub: &Publisher,
    action: Action<DaoWitness, CoinType, TransferQuadraticWalletPayload>, 
    ctx: &mut TxContext    
  ): QuadraticWallet<CoinType> {
    complete_rule(TreasuryActionWitness {}, &mut action);
    let payload = finish_action(action);
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
    
    wallet
  }


  public fun create_transfer_payload<CoinType>(value: u64, publisher_id: ID): TransferPayload {
    TransferPayload {
      type: get<CoinType>(),
      value,
      publisher_id
    }
  }

  public fun create_transfer_linear_vesting_wallet_payload<CoinType>(
    value: u64, 
    publisher_id: ID,
    start: u64, 
    duration: u64
  ): TransferVestingWalletPayload {
    TransferVestingWalletPayload {
      type: get<CoinType>(),
      value,
      publisher_id,
      start,
      duration
    }
  }

  public fun create_transfer_quadratic_vesting_wallet_payload<CoinType>(
    value: u64, 
    publisher_id: ID,
    cliff: u64, 
    start: u64,
    vesting_curve_a: u64,
    vesting_curve_b: u64,
    vesting_curve_c: u64,
    duration: u64
  ): TransferQuadraticWalletPayload {
    TransferQuadraticWalletPayload {
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

  // Flash loan logic

  public fun flash_loan<DaoWitness: drop, CoinType>(treasury: &mut DaoTreasury<DaoWitness>, value: u64, ctx: &mut TxContext):(Coin<CoinType>, FlashLoan<DaoWitness, CoinType>) {
    assert!(treasury.allow_flashloan, EFlashloanNotAllowed);
    let type = get<CoinType>();
    let initial_balance = balance::value(bag::borrow<TypeName, Balance<CoinType>>(&treasury.coins, type));

    emit(FlashLoanRequest<DaoWitness, CoinType> { type, borrower: tx_context::sender(ctx), value, treasury_id: object::id(treasury) });

    (
      coin::take<CoinType>(bag::borrow_mut(&mut treasury.coins, type), value, ctx),
      FlashLoan { initial_balance , type, fee: (roll_mul_up((value as u128), FLASH_LOAN_FEE) as u64) }
    )
  }

  public fun view_flash_loan<DaoWitness: drop, CoinType>(flash_loan: &FlashLoan<DaoWitness, CoinType>): (TypeName, u64) {
    (flash_loan.type, flash_loan.fee)
  }

  public fun repay_flash_loan<DaoWitness: drop, CoinType>(
    treasury: &mut DaoTreasury<DaoWitness>, 
    flash_loan: FlashLoan<DaoWitness, CoinType>,
    token: Coin<CoinType>
  ) {
    let FlashLoan { initial_balance, type, fee } = flash_loan;
    balance::join(bag::borrow_mut(&mut treasury.coins, type), coin::into_balance(token));

    let final_balance = initial_balance + fee;
    assert!(final_balance >= balance::value(bag::borrow<TypeName, Balance<CoinType>>(&treasury.coins, type)), ERepayAmountTooLow);
  }
}
