/*
* @title Farm
*
* @notice A contract to distribute reward tokens to stakers. 
*
* @dev All times are in seconds.
*/
module suitears::farm {
  use sui::math;
  use sui::event::emit;
  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::tx_context::{Self, TxContext};
  use sui::coin::{Self, Coin, CoinMetadata};

  use suitears::math256;
  use suitears::owner::{Self, OwnerCap};

  // Errors
  const EInsufficientStakeAmount: u64 = 0;
  const EAccountHasValue: u64 = 1;
  const ENoPendingRewards: u64 = 2;
  const EInvalidStartTime: u64 = 3;
  const EInvalidRewardsPerSecond: u64 = 4;

  struct FarmWitness has drop {}

  struct Account<phantom Label, phantom StakeCoin, phantom RewardCoin> has key, store {
    id: UID,
    amount: u64,
    reward_debt: u256
  }

  struct Farm<phantom Label, phantom StakeCoin, phantom RewardCoin> has key, store {
    id: UID,
    rewards_per_second: u64,
    start_timestamp: u64,
    last_reward_timestamp: u64,
    accrued_rewards_per_share: u256,
    balance_stake_coin: Balance<StakeCoin>,
    balance_reward_coin: Balance<RewardCoin>,
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

  public fun new_cap(ctx: &mut TxContext): OwnerCap<FarmWitness> {
    owner::new(FarmWitness {}, vector[], ctx)
  }

  public fun new_account<Label: drop, StakeCoin, RewardCoin>(_: Label, ctx: &mut TxContext): Account<Label, StakeCoin, RewardCoin> {
    Account {
      id: object::new(ctx),
      amount: 0,
      reward_debt: 0
    }
  }

  public fun new_farm<Label: drop, StakeCoin, RewardCoin>(
    cap: &mut OwnerCap<FarmWitness>,
    stake_coin_metadata: &CoinMetadata<StakeCoin>,
    c: &Clock,
    rewards_per_second: u64,
    start_timestamp: u64,
    ctx: &mut TxContext
  ): Farm<Label, StakeCoin, RewardCoin> {
    assert!(clock_timestamp_s(c) > start_timestamp, EInvalidStartTime);
    assert!(rewards_per_second != 0, EInvalidRewardsPerSecond);

    let cap_id = object::id(cap);

    let farm = Farm {
      id: object::new(ctx),
      start_timestamp,
      last_reward_timestamp: start_timestamp,
      rewards_per_second,
      accrued_rewards_per_share: 0,
      stake_coin_decimal_factor: math::pow(10, coin::get_decimals(stake_coin_metadata)),
      owned_by: cap_id,
      balance_stake_coin: balance::zero(),
      balance_reward_coin: balance::zero(),     
    };

    let farm_id = object::id(&farm);

    owner::add( cap, FarmWitness {}, farm_id);
    
    emit(CreateFarm<Label, StakeCoin, RewardCoin>{ farm: farm_id, cap: cap_id, sender: tx_context::sender(ctx) });
    
    farm
  }

  public fun add_rewards<Label, StakeCoin, RewardCoin>(farm: &mut Farm<Label, StakeCoin, RewardCoin>, reward: Coin<RewardCoin>) {
    let farm_id = object::id(farm);
    emit(AddReward<Label, StakeCoin, RewardCoin> { farm: farm_id, value: coin::value(&reward) });
    balance::join(&mut farm.balance_reward_coin, coin::into_balance(reward));
  }

  public fun stake<Label, StakeCoin, RewardCoin>(
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    account: &mut Account<Label, StakeCoin, RewardCoin>,
    stake_coin: Coin<StakeCoin>, 
    c: &Clock,
    ctx: &mut TxContext
  ): Coin<RewardCoin> {
    update(farm, clock_timestamp_s(c));

    let stake_amount = coin::value(&stake_coin);

    let reward_coin = coin::zero<RewardCoin>(ctx);

    if (account.amount != 0) {
      let pending_reward = calculate_pending_rewards(
        account, 
        farm.stake_coin_decimal_factor, 
        farm.accrued_rewards_per_share
      );
      if (pending_reward != 0) coin::join(&mut reward_coin, coin::take(&mut farm.balance_reward_coin, pending_reward, ctx));
    };

    if (stake_amount != 0) {
      balance::join(&mut farm.balance_stake_coin, coin::into_balance(stake_coin));
      account.amount = account.amount + stake_amount;
    } else {
      coin::destroy_zero(stake_coin);
    };

    account.reward_debt = calculate_reward_debt(
      account.amount, 
      farm.stake_coin_decimal_factor, 
      farm.accrued_rewards_per_share
    );

    emit(Stake<Label, StakeCoin, RewardCoin> { farm: object::id(farm), stake_amount, reward_amount: coin::value(&reward_coin), sender: tx_context::sender(ctx) });

    reward_coin
  }

  public fun unstake<Label, StakeCoin, RewardCoin>(
    c: &Clock,
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    account: &mut Account<Label, StakeCoin, RewardCoin>,
    amount: u64,
    ctx: &mut TxContext
  ): (Coin<StakeCoin>, Coin<RewardCoin>) {
    let now = clock_timestamp_s(c);
    update(farm, now);


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

    emit(Unstake<Label, StakeCoin, RewardCoin> { farm: object::id(farm), unstake_amount: amount, reward_amount: pending_reward, sender: tx_context::sender(ctx) });

    (stake_coin, reward_coin)
  }

  public fun update_farm_limit_per_user<Label, StakeCoin, RewardCoin>(
    cap: &OwnerCap<FarmWitness>, 
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    c: &Clock, 
    new_farm_limit_per_user: u64,
    ctx: &mut TxContext
  ) {
    owner::assert_ownership(cap, object::id(farm));
    
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
    cap: &OwnerCap<FarmWitness>, 
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    c: &Clock, 
    new_reward_per_second: u64,
    ctx: &mut TxContext
  ) {
    owner::assert_ownership(cap, object::id(farm));
    assert!(farm.start_timestamp > clock_timestamp_s(c), EFarmAlreadyStarted);

    farm.reward_per_second = new_reward_per_second;

    emit(NewRewardRate<Label, StakeCoin, RewardCoin> { farm: object::id(farm), rate: new_reward_per_second, sender: tx_context::sender(ctx)});
  }

  public fun update_start_and_end_timestamp<Label, StakeCoin, RewardCoin>(
    cap: &OwnerCap<FarmWitness>, 
    farm: &mut Farm<Label, StakeCoin, RewardCoin>, 
    c: &Clock, 
    start_timestamp: u64,
    end_timestamp: u64,
    ctx: &mut TxContext
  ) {
    owner::assert_ownership(cap, object::id(farm));

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

  public fun get_user_stake_amount<Label, StakeCoin, RewardCoin>(account: &Account<Label, StakeCoin, RewardCoin>): u64 {
    account.amount
  }

  public fun get_pending_reward<Label, StakeCoin, RewardCoin>(
    c: &Clock, 
    farm: &Farm<Label, StakeCoin, RewardCoin>, 
    account: &Account<Label, StakeCoin, RewardCoin>
  ): u64 {
    
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

    calculate_pending_rewards(account, farm.stake_coin_decimal_factor, account_token_per_share)
  }  

  public fun destroy_farm<Label, StakeCoin, RewardCoin>(cap: &OwnerCap<FarmWitness>, farm: Farm<Label, StakeCoin, RewardCoin>) {
    owner::assert_ownership(cap, object::id(&farm));
    let Farm {
      id, 
      balance_reward_coin, 
      balance_stake_coin, 
      owned_by: _, 
      rewards_per_second: _,
      start_timestamp: _,
      last_reward_timestamp: _,
      accrued_rewards_per_share: _,
      stake_coin_decimal_factor: _,
    } = farm;

    object::delete(id);
    balance::destroy_zero(balance_reward_coin);
    balance::destroy_zero(balance_stake_coin)
  }

  public fun destroy_account<Label, StakeCoin, RewardCoin>(account: Account<Label, StakeCoin, RewardCoin>) {
    let Account { id, amount, reward_debt: _ } = account;
    assert!(amount == 0, EAccountHasValue);
    object::delete(id);
  }

  // @dev Can attach the Account to the farm and other data
  public fun borrow_mut_uid<Label, StakeCoin, RewardCoin>(cap: &OwnerCap<FarmWitness>, self: &mut Farm<Label, StakeCoin, RewardCoin>): &mut UID {
    owner::assert_ownership(cap, object::id(self));
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

    let total_reward_value = balance::value(&farm.balance_reward_coin);

    farm.accrued_rewards_per_share = calculate_accrued_rewards_per_share(
      farm.rewards_per_second,
      farm.accrued_rewards_per_share,
      total_staked_value,
      total_reward_value,
      farm.stake_coin_decimal_factor,
      now - farm.last_reward_timestamp
    );
  }

  fun calculate_accrued_rewards_per_share(
    rewards_per_second: u64,
    last_accrued_rewards_per_share: u256,
    total_staked_token: u64,
    total_reward_value: u64,
    stake_factor: u64,
    timestamp_delta: u64
  ): u256 { 
    
    let (total_staked_token, total_reward_value, rewards_per_second, stake_factor, timestamp_delta) =
     (
      (total_staked_token as u256),
      (total_reward_value as u256),
      (rewards_per_second as u256),
      (stake_factor as u256),
      (timestamp_delta as u256)
     );
    
    let reward = math256::min(total_reward_value, rewards_per_second * timestamp_delta);

    last_accrued_rewards_per_share + ((reward * stake_factor) / total_staked_token)
  }

  fun calculate_pending_rewards<Label, StakeCoin, RewardCoin>(acc: &Account<Label, StakeCoin, RewardCoin>, stake_factor: u64, account_token_per_share: u256): u64 {
    ((((acc.amount as u256) * account_token_per_share / (stake_factor as u256)) - acc.reward_debt) as u64)
  }

  fun calculate_reward_debt(stake_amount: u64, stake_factor: u64, account_token_per_share: u256): u256 {
    let (stake_amount, stake_factor) = (
      (stake_amount as u256),
      (stake_factor as u256)
    );

    (stake_amount * account_token_per_share) / stake_factor
  }
}