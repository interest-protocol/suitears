// Credits: https://github.com/pancakeswap/pancake-contracts-move/blob/main/pancake-smart-chef/sources/smart_chef.move
// ** IMPORTANT ALL TIMESTAMPS IN SECOND
module suitears::farm {
  use std::type_name;

  use sui::math;
  use sui::event::emit;
  use sui::clock::{Self, Clock};
  use sui::table::{Self, Table};
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::tx_context::{Self, TxContext};
  use sui::coin::{Self, Coin, CoinMetadata};

  use suitears::owner::{Self, OwnerCap};

  // Errors
  const EInvalidStartTime: u64 = 0;
  const EInvalidEndTime: u64 = 1;
  const ESameCoin: u64 = 2;
  const EFarmLimitZero: u64 = 3;
  const EFarmEnded: u64 = 4;
  const EStakeAboveLimit: u64 = 5;
  const EInsufficientStakeAmount: u64 = 6;
  const ENoLimitSet: u64 = 7;
  const ELimitPerUserMustBeHigher: u64 = 8;
  const EFarmAlreadyStarted: u64 = 9;

  struct FarmWitness has drop {}

  struct FarmCap has key, store {
    id: UID,
    cap: OwnerCap<FarmWitness>,
  }

  struct Account has store, drop {
    amount: u64,
    reward_debt: u256
  }

  struct Farm<phantom Label, phantom StakeCoin, phantom RewardCoin> has key, store {
    id: UID,
    balance_stake_coin: Balance<StakeCoin>,
    balance_reward_coin: Balance<RewardCoin>,
    accounts: Table<address, Account>,
    reward_per_second: u64,
    start_timestamp: u64,
    end_timestamp: u64,
    last_reward_timestamp: u64,
    seconds_for_user_limit: u64,
    farm_limit_per_user: u64,
    account_token_per_share: u256,
    stake_coin_decimal_factor: u64,
    owned_by: ID
  }

  // Events

  struct CreateFarm<phantom Label, phantom StakeCoin, phantom RewardCoin> has drop, copy {
    farm: ID,
    cap: ID,
    sender: address
  }

  struct AddReward<phantom Label, phantom StakeCoin, phantom RewardCoin> has drop, copy {
    farm: ID,
    cap: ID,
    value: u64
  }

  struct Stake<phantom Label, phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    stake_amount: u64,
    reward_amount: u64,
    sender: address
  }

  struct Unstake<phantom Label, phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    unstake_amount: u64,
    reward_amount: u64,
    sender: address
  }

  struct StopReward<phantom Label, phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    timestamp: u64,
    sender: address
  }

  struct UpdateLimitPerUser<phantom Label, phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    new_limit: u64,
    sender: address
  }

  struct NewRewardRate<phantom Label, phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    rate: u64, 
    sender: address
  }

  struct NewDates<phantom Label, phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    start_timestamp: u64,
    end_timestamp: u64,
    sender: address
  }

  public fun create_cap(ctx: &mut TxContext): FarmCap {
    FarmCap {
      id: object::new(ctx),
      cap: owner::create(FarmWitness {}, vector[], ctx)
    }
  }

  public fun create_farm<Label, StakeCoin, RewardCoin>(
    cap: &mut FarmCap,
    stake_coin_metadata: &CoinMetadata<StakeCoin>,
    c: &Clock,
    reward_per_second: u64,
    start_timestamp: u64,
    end_timestamp: u64,
    farm_limit_per_user: u64,
    seconds_for_user_limit: u64,
    ctx: &mut TxContext
  ): Farm<Label, StakeCoin, RewardCoin> {
    assert!(clock_timestamp_s(c) > start_timestamp, EInvalidStartTime);
    assert!(end_timestamp > start_timestamp, EInvalidEndTime);
    assert!(type_name::get<StakeCoin>() != type_name::get<RewardCoin>(), ESameCoin);

    if (seconds_for_user_limit != 0) {
      assert!(farm_limit_per_user != 0, EFarmLimitZero);
    };

    let cap_id = object::id(cap);

    let farm = Farm {
      id: object::new(ctx),
      balance_stake_coin: balance::zero(),
      balance_reward_coin: balance::zero(),
      accounts: table::new(ctx),
      reward_per_second,
      start_timestamp,
      end_timestamp,
      last_reward_timestamp: start_timestamp,
      seconds_for_user_limit,
      farm_limit_per_user,
      account_token_per_share: 0,
      stake_coin_decimal_factor: math::pow(10, coin::get_decimals(stake_coin_metadata)),
      owned_by: cap_id     
    };

    let farm_id = object::id(&farm);

    owner::add(FarmWitness {}, &mut cap.cap, farm_id);
    
    emit(CreateFarm<Label, StakeCoin, RewardCoin>{ farm: farm_id, cap: cap_id, sender: tx_context::sender(ctx) });
    
    farm
  }

  public fun add_reward<Label, StakeCoin, RewardCoin>(cap: &FarmCap, farm: &mut Farm<Label, StakeCoin, RewardCoin>, reward: Coin<RewardCoin>) {
    let farm_id = object::id(farm);
    owner::assert_ownership(&cap.cap, farm_id);
    emit(AddReward<Label, StakeCoin, RewardCoin> { farm: farm_id, cap: object::id(cap), value: coin::value(&reward) });
    balance::join(&mut farm.balance_reward_coin, coin::into_balance(reward));
  }

  public fun stake<Label, StakeCoin, RewardCoin>(
    c: &Clock,
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    stake_coin: Coin<StakeCoin>, 
    ctx: &mut TxContext
  ): Coin<RewardCoin> {
    let now = clock_timestamp_s(c);
    assert!(farm.end_timestamp > now, EFarmEnded);

    let sender = tx_context::sender(ctx);

    if (!table::contains(&farm.accounts, sender)) 
      table::add(&mut farm.accounts, sender, Account { amount: 0, reward_debt: 0 });
    
    update(farm, now);

    let account = table::borrow_mut(&mut farm.accounts, sender);
    let stake_amount = coin::value(&stake_coin);
    
    assert!(farm.farm_limit_per_user >= account.amount + stake_amount || now >= (farm.start_timestamp + farm.seconds_for_user_limit), EStakeAboveLimit);

    let reward_coin = coin::zero<RewardCoin>(ctx);

    if (account.amount != 0) {
      let pending_reward = calculate_pending_rewards(account, farm.stake_coin_decimal_factor, farm.account_token_per_share);
      if (pending_reward != 0) coin::join(&mut reward_coin, coin::take(&mut farm.balance_reward_coin, pending_reward, ctx));
    };

    if (stake_amount != 0) {
      balance::join(&mut farm.balance_stake_coin, coin::into_balance(stake_coin));
      account.amount = account.amount + stake_amount;
    } else {
      coin::destroy_zero(stake_coin);
    };

    account.reward_debt = reward_debt(account.amount, farm.stake_coin_decimal_factor, farm.account_token_per_share);

    emit(Stake<Label, StakeCoin, RewardCoin> { farm: object::id(farm), stake_amount, reward_amount: coin::value(&reward_coin), sender });

    reward_coin
  }

  public fun unstake<Label, StakeCoin, RewardCoin>(
    c: &Clock,
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    amount: u64,
    ctx: &mut TxContext
  ): (Coin<StakeCoin>, Coin<RewardCoin>) {
    let now = clock_timestamp_s(c);
    update(farm, now);

    let sender = tx_context::sender(ctx);
    let account = table::borrow_mut(&mut farm.accounts, sender);

    assert!(account.amount >= amount, EInsufficientStakeAmount);

    let pending_reward = calculate_pending_rewards(account, farm.stake_coin_decimal_factor, farm.account_token_per_share);

    let stake_coin = coin::zero<StakeCoin>(ctx);
    let reward_coin = coin::zero<RewardCoin>(ctx);

    if (amount != 0) {
      account.amount = account.amount - amount;
      coin::join(&mut stake_coin, coin::take(&mut farm.balance_stake_coin, amount, ctx));
    };

    if (pending_reward != 0) {
      coin::join(&mut reward_coin, coin::take(&mut farm.balance_reward_coin, amount, ctx));      
    };

    account.reward_debt = reward_debt(account.amount, farm.stake_coin_decimal_factor, farm.account_token_per_share);

    emit(Unstake<Label, StakeCoin, RewardCoin> { farm: object::id(farm), unstake_amount: amount, reward_amount: pending_reward, sender });

    (stake_coin, reward_coin)
  }

  public fun stop_reward<Label, StakeCoin, RewardCoin>(cap: &FarmCap, farm: &mut Farm<Label, StakeCoin, RewardCoin>, c:&Clock, ctx: &mut TxContext) {
    owner::assert_ownership(&cap.cap, object::id(farm));
    
    let now = clock_timestamp_s(c);
    farm.end_timestamp = now;
    emit(StopReward<Label, StakeCoin, RewardCoin>{ farm: object::id(farm), timestamp: now, sender: tx_context::sender(ctx) });
  }

  public fun update_farm_limit_per_user<Label, StakeCoin, RewardCoin>(
    cap: &FarmCap, 
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    c: &Clock, 
    new_farm_limit_per_user: u64,
    ctx: &mut TxContext
  ) {
    owner::assert_ownership(&cap.cap, object::id(farm));
    
    assert!(farm.seconds_for_user_limit > 0 && (farm.start_timestamp + farm.seconds_for_user_limit) > clock_timestamp_s(c), ENoLimitSet);

    if (new_farm_limit_per_user == 0) {
      farm.seconds_for_user_limit = 0; 
      farm.farm_limit_per_user = 0;
    } else {
      assert!(new_farm_limit_per_user > farm.farm_limit_per_user, ELimitPerUserMustBeHigher);
      farm.farm_limit_per_user = new_farm_limit_per_user;
    };

    emit(UpdateLimitPerUser<Label, StakeCoin, RewardCoin> { farm: object::id(farm), new_limit: new_farm_limit_per_user, sender: tx_context::sender(ctx) });
  }

  public fun update_reward_per_second<Label, StakeCoin, RewardCoin>(
    cap: &FarmCap, 
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    c: &Clock, 
    new_reward_per_second: u64,
    ctx: &mut TxContext
  ) {
    owner::assert_ownership(&cap.cap, object::id(farm));
    assert!(farm.start_timestamp > clock_timestamp_s(c), EFarmAlreadyStarted);

    farm.reward_per_second = new_reward_per_second;

    emit(NewRewardRate<Label, StakeCoin, RewardCoin> { farm: object::id(farm), rate: new_reward_per_second, sender: tx_context::sender(ctx)});
  }

  public fun update_start_and_end_timestamp<Label, StakeCoin, RewardCoin>(
    cap: &FarmCap, 
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    c: &Clock, 
    start_timestamp: u64,
    end_timestamp: u64,
    ctx: &mut TxContext
  ) {
    owner::assert_ownership(&cap.cap, object::id(farm));

    let now = clock_timestamp_s(c);
    assert!(farm.start_timestamp > now, EFarmAlreadyStarted);
    assert!(end_timestamp > start_timestamp, EInvalidEndTime);
    assert!(start_timestamp > now, EInvalidStartTime);

    farm.start_timestamp = start_timestamp;
    farm.end_timestamp = end_timestamp;
    farm.last_reward_timestamp = start_timestamp;

    emit(NewDates<Label, StakeCoin, RewardCoin> { farm: object::id(farm), start_timestamp, end_timestamp, sender: tx_context::sender(ctx)});
  }

  public fun get_farm_info<Label, StakeCoin, RewardCoin>(farm: &Farm<Label, StakeCoin, RewardCoin>): (u64, u64, u64, u64, u64, u64, u64) {
    (
      balance::value(&farm.balance_stake_coin),
      balance::value(&farm.balance_reward_coin),
      farm.reward_per_second,
      farm.start_timestamp,
      farm.end_timestamp,
      farm.seconds_for_user_limit,
      farm.farm_limit_per_user
    )
  }

  public fun get_user_stake_amount<Label, StakeCoin, RewardCoin>(farm: &Farm<Label, StakeCoin, RewardCoin>, ctx: &mut TxContext): u64 {
    let sender = tx_context::sender(ctx);
    if (!table::contains(&farm.accounts, sender)) return 0;

    table::borrow(&farm.accounts, sender).amount
  }

  public fun get_pending_reward<Label, StakeCoin, RewardCoin>(farm: &Farm<Label, StakeCoin, RewardCoin>, c: &Clock, ctx: &mut TxContext): u64 {

    let sender = tx_context::sender(ctx);
    if (!table::contains(&farm.accounts, sender)) return 0;
    
    let total_staked_value = balance::value(&farm.balance_stake_coin);
    let now = clock_timestamp_s(c);

    let account_token_per_share = if (total_staked_value == 0 || farm.last_reward_timestamp >= now) {
      farm.account_token_per_share
    } else {
      calculate_account_token_per_share(
        now,
        farm.account_token_per_share,
        total_staked_value,
        farm.end_timestamp,
        farm.reward_per_second,
        farm.stake_coin_decimal_factor,
        farm.last_reward_timestamp
      )
    };

    calculate_pending_rewards(table::borrow(&farm.accounts, sender), farm.stake_coin_decimal_factor, account_token_per_share)
  }  

  public fun destroy_cap(cap: FarmCap) {
    let FarmCap { id, cap } = cap;
    object::delete(id);
    owner::destroy(cap);
  }

  public fun destroy_farm<Label, StakeCoin, RewardCoin>(cap: &FarmCap, farm: Farm<Label, StakeCoin, RewardCoin>) {
    owner::assert_ownership(&cap.cap, object::id(&farm));
    let Farm {
      id, 
      balance_reward_coin, 
      balance_stake_coin, 
      owned_by: _, 
      reward_per_second: _,
      start_timestamp: _,
      end_timestamp: _,
      last_reward_timestamp: _,
      seconds_for_user_limit: _,
      farm_limit_per_user: _,
      account_token_per_share: _,
      stake_coin_decimal_factor: _,
      accounts
    } = farm;

    object::delete(id);
    table::drop(accounts);
    balance::destroy_zero(balance_reward_coin);
    balance::destroy_zero(balance_stake_coin)
  }

  // @dev Can attach the Account to the farm and other data
  public fun borrow_mut_uid<Label, StakeCoin, RewardCoin>(cap: &FarmCap, self: &mut Farm<Label, StakeCoin, RewardCoin>): &mut UID {
    owner::assert_ownership(&cap.cap, object::id(self));
    &mut self.id    
  }

  fun clock_timestamp_s(c: &Clock): u64 {
    clock::timestamp_ms(c) / 1000
  }

  fun update<Label, StakeCoin, RewardCoin>(farm: &mut Farm<Label, StakeCoin, RewardCoin>, now: u64) {
    if (farm.last_reward_timestamp >= now) return;

    let total_staked_value = balance::value(&farm.balance_stake_coin);

    if (total_staked_value == 0) {
      farm.last_reward_timestamp = now;
      return
    };

    let new_account_token_per_share = calculate_account_token_per_share(
      now,
      farm.account_token_per_share,
      total_staked_value,
      farm.end_timestamp,
      farm.reward_per_second,
      farm.stake_coin_decimal_factor,
      farm.last_reward_timestamp
    );

    if (farm.account_token_per_share != new_account_token_per_share) {
      farm.account_token_per_share = new_account_token_per_share;
      farm.last_reward_timestamp = now;
    };
  }

  fun calculate_account_token_per_share(
    now: u64,
    last_account_token_per_share: u256,
    total_staked_token: u64,
    end_timestamp: u64,
    reward_per_second: u64,
    stake_factor: u64,
    last_reward_timestamp: u64
  ): u256 { 
    let multiplier = get_multiplier(last_reward_timestamp, now, end_timestamp);
    let (total_staked_token, reward_per_second, stake_factor, multiplier) =
     (
      (total_staked_token as u256),
      (reward_per_second as u256),
      (stake_factor as u256),
      (multiplier as u256)
     );
    
    let reward = reward_per_second * multiplier;
    if (multiplier == 0) return last_account_token_per_share;

    last_account_token_per_share + ((reward * stake_factor) / total_staked_token)
  }

  fun calculate_pending_rewards(acc: &Account, stake_factor: u64, account_token_per_share: u256): u64 {
    let stake_factor = (stake_factor as u256);

    ((((acc.amount as u256) * account_token_per_share / stake_factor) - acc.reward_debt) as u64)
  }

  fun reward_debt(stake_amount: u64, stake_factor: u64, account_token_per_share: u256): u256 {
    let (stake_amount, stake_factor) = (
      (stake_amount as u256),
      (stake_factor as u256)
    );

    (stake_amount * account_token_per_share) / stake_factor
  }

  fun get_multiplier(from: u64, to: u64, end: u64): u64 {
    if (end >= to) { to - from } else if ( from >= end ) { 0 } else { end - from }
  }
}