/*
* @title Farm
*
* @notice A contract to distribute reward tokens to stakers. 
*
* @dev All times are in seconds.
*/
module suitears::farm {
  // === Imports ===   

  use sui::math;
  use sui::event::emit;
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin, CoinMetadata};

  use suitears::math64;
  use suitears::math256;
  use suitears::owner::{Self, OwnerCap};

  // === Errors ===

  // @dev Thrown when the user tries to unstake more than his total stake amount. 
  const EInsufficientStakeAmount: u64 = 0;

  // @dev Thrown when the user tries to destroy an {Account} that still has a deposit in the {Farm}. 
  const EAccountHasValue: u64 = 1;
  
  // @dev Thrown when the user tries to create a {Farm} that starts in the past. 
  const EInvalidStartTime: u64 = 3;
  
  // @dev Thrown when the user uses the wrong {Account}. 
  const EInvalidAccount: u64 = 5;

  // === Structs ===  

  // @dev To associate the {OwnerCap} with this module. 
  struct FarmWitness has drop {}
  
  struct Account<phantom StakeCoin, phantom RewardCoin> has key, store {
    id: UID,
    // The `sui::object::ID` of the farm to which this account belongs to. 
    farm_id: ID,
    // The amount of {StakeCoin} the user has in the {Farm}.  
    amount: u64,
    // Amount of rewards the {Farm} has already paid the user.  
    reward_debt: u256
  }

  struct Farm<phantom StakeCoin, phantom RewardCoin> has key, store {
    id: UID,
    // Amount of {RewardCoin} to give to stakers per second.  
    rewards_per_second: u64,
    // The timestamp in seconds that this farm will start distributing rewards.  
    start_timestamp: u64,
    // Last timestamp that the farm was updated. 
    last_reward_timestamp: u64,
    // Total amount of rewards per share distributed by this farm.   
    accrued_rewards_per_share: u256,
    // {StakeCoin} deposited in this farm. 
    balance_stake_coin: Balance<StakeCoin>,
    // {RewardCoin} deposited in this farm. 
    balance_reward_coin: Balance<RewardCoin>,
    // The decimal scalar of the {StakeCoin}.  
    stake_coin_decimal_factor: u64,
    // The `sui::object::ID` of the {OwnerCap} that "owns" this farm. 
    owned_by: ID
  }

  // === Events ===  

  struct NewFarm<phantom StakeCoin, phantom RewardCoin> has drop, copy {
    farm: ID,
    cap: ID,
  }

  struct AddReward<phantom StakeCoin, phantom RewardCoin> has drop, copy {
    farm: ID,
    value: u64
  }

  struct Stake<phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    stake_amount: u64,
    reward_amount: u64
  }

  struct Unstake<phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    unstake_amount: u64,
    reward_amount: u64
  }

  struct NewRewardRate<phantom StakeCoin, phantom RewardCoin> has copy, drop {
    farm: ID,
    rate: u64
  }

  // === Public Create Functions ===  

  /*
  * @notice It creates an {OwnerCap<FarmWitness>}. 
  * It is used to provide admin capabilities to the holder.
  *
  * @return {OwnerCap<FarmWitness>}. 
  */
  public fun new_cap(ctx: &mut TxContext): OwnerCap<FarmWitness> {
    owner::new(FarmWitness {}, vector[], ctx)
  }

  /*
  * @notice It creates an {Farm<StakeCoin, RewardCoin>}. 
  *
  * @dev The `start_timestamp` is in seconds.
  *
  * @param cap An {OwnerCap} that will be assigned the admin rights of the newly created {Farm}.  
  * @param stake_coin_metadata The `sui::coin::CoinMetadata` of the `StakeCoin`.  
  * @param c The `sui::clock::Clock` shared object.   
  * @param rewards_per_second The amount of `RewardCoin` the farm can distribute to stakers.  
  * @param start_timestamp The timestamp in seconds that the farm is allowed to start distributing rewards.  
  * @return {Farm<StakeCoin, RewardCoin>}. 
  *
  * aborts-if:  
  * - `start_timestamp` is in the past. 
  */
  public fun new_farm<StakeCoin, RewardCoin>(
    cap: &mut OwnerCap<FarmWitness>,
    stake_coin_metadata: &CoinMetadata<StakeCoin>,
    c: &Clock,
    rewards_per_second: u64,
    start_timestamp: u64,
    ctx: &mut TxContext
  ): Farm<StakeCoin, RewardCoin> {
    assert!(start_timestamp > clock_timestamp_s(c), EInvalidStartTime);
    
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
    
    emit(NewFarm<StakeCoin, RewardCoin>{ farm: farm_id, cap: cap_id });
    
    farm
  }

  /*
  * @notice It creates an {Account<StakeCoin, RewardCoin>}. 
  * It is used to keep track of the holder's deposit and rewards. 
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return {Account<StakeCoin, RewardCoin>}. 
  */
  public fun new_account<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>, ctx: &mut TxContext): Account<StakeCoin, RewardCoin> {
    Account {
      id: object::new(ctx),
      farm_id: object::id(self),
      amount: 0,
      reward_debt: 0
    }
  }  

  // === Public View Functions ===  

  /*
  * @notice Returns the `self` rewards per second. 
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return u64. 
  */
  public fun rewards_per_second<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>): u64 {
    self.rewards_per_second
  }

  /*
  * @notice Returns the `self` start timestamp. 
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return u64. 
  */
  public fun start_timestamp<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>): u64 {
    self.start_timestamp
  } 

  /*
  * @notice Returns the `self` last reward timestamp. 
  *
  * @dev It is in seconds.
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return u64. 
  */
  public fun last_reward_timestamp<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>): u64 {
    self.last_reward_timestamp
  }   

  /*
  * @notice Returns the `self` accrued rewards per share. 
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return u256. 
  */
  public fun accrued_rewards_per_share<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>): u256 {
    self.accrued_rewards_per_share
  }   

  /*
  * @notice Returns the `self` stake coin balance. 
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return u64. 
  */
  public fun balance_stake_coin<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>): u64 {
    balance::value(&self.balance_stake_coin)
  }  

  /*
  * @notice Returns the `self` reward coin balance. 
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return u64. 
  */
  public fun balance_reward_coin<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>): u64 {
    balance::value(&self.balance_reward_coin)
  }  

  /*
  * @notice Returns the `self` reward coin decimal scalar. 
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return u64. 
  */
  public fun stake_coin_decimal_factor<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>): u64 {
    self.stake_coin_decimal_factor
  }   

  /*
  * @notice Returns the `self` {OwnerCap} `sui::object::ID`. 
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}
  * @return ID. 
  */
  public fun owned_by<StakeCoin, RewardCoin>(self: &Farm<StakeCoin, RewardCoin>): ID {
    self.owned_by
  } 

  /*
  * @notice Returns the `account` staked amount. 
  *
  * @param account An {Account}
  * @return u64. 
  */
  public fun amount<StakeCoin, RewardCoin>(account: &Account<StakeCoin, RewardCoin>): u64 {
    account.amount
  }

  /*
  * @notice Returns the `account` reward debt. 
  *
  * @param account An {Account}
  * @return u256. 
  */
  public fun reward_debt<StakeCoin, RewardCoin>(account: &Account<StakeCoin, RewardCoin>): u256 {
    account.reward_debt
  }  

  /*
  * @notice Returns the `account`'s pending rewards. 
  *
  * @dev It does not update the state.
  *
  * @param farm The {Farm<StakeCoin, RewardCoin>}.  
  * @param account The {Account} associated with the `farm`.
  * @param c The `sui::clock::Clock` shared object.    
  * @return u64. 
  */
  public fun pending_rewards<StakeCoin, RewardCoin>(
    farm: &Farm<StakeCoin, RewardCoin>, 
    account: &Account<StakeCoin, RewardCoin>,
    c: &Clock, 
  ): u64 {
    if (object::id(farm) != account.farm_id) return 0;

    let total_staked_value = balance::value(&farm.balance_stake_coin);
    let now = clock_timestamp_s(c);

    let accrued_rewards_per_share = if (total_staked_value == 0 || farm.last_reward_timestamp >= now) {
      farm.accrued_rewards_per_share
    } else {
      calculate_accrued_rewards_per_share(
      farm.rewards_per_second,
      farm.accrued_rewards_per_share,
      total_staked_value,
      balance::value(&farm.balance_reward_coin),
      farm.stake_coin_decimal_factor,
      now - farm.last_reward_timestamp
      )
    };

    calculate_pending_rewards(account, farm.stake_coin_decimal_factor, accrued_rewards_per_share)
  }      

  // === Public Mutative Functions ===              

  /*
  * @notice It allows anyone to add rewards to the `farm`.
  *
  * @param self The {Farm<StakeCoin, RewardCoin>}.  
  * @param c The `sui::clock::Clock` shared object.    
  * @param reward The {RewardCoin} to be added to the `self`.    
  */
  public fun add_rewards<StakeCoin, RewardCoin>(self: &mut Farm<StakeCoin, RewardCoin>, c: &Clock, reward: Coin<RewardCoin>) {
    update(self, clock_timestamp_s(c));
    let farm_id = object::id(self);
    emit(AddReward<StakeCoin, RewardCoin> { farm: farm_id, value: coin::value(&reward) });
    balance::join(&mut self.balance_reward_coin, coin::into_balance(reward));
  }

  /*
  * @notice Allows a user to stake `stake_coin` in the `farm`.
  *
  * @dev On the first deposits the returned Coin will have a value of zero. So make sure to destroy it. 
  * 
  * @param farm The {Farm<StakeCoin, RewardCoin>}.  
  * @param account The {Account} associated with the `farm`. 
  * @param stake_coin The {StakeCoin} to stake in the `farm`.     
  * @param c The `sui::clock::Clock` shared object.  
  * @return Coin<RewardCoin>. It gives any pending rewards to the user. 
  *
  * aborts-if:  
  * - `account` does not belong to the `farm`.  
  */
  public fun stake<StakeCoin, RewardCoin>(
    farm: &mut Farm<StakeCoin, RewardCoin>, 
    account: &mut Account<StakeCoin, RewardCoin>,
    stake_coin: Coin<StakeCoin>, 
    c: &Clock,
    ctx: &mut TxContext
  ): Coin<RewardCoin> {
    assert!(object::id(farm) == account.farm_id, EInvalidAccount);

    update(farm, clock_timestamp_s(c));

    let stake_amount = coin::value(&stake_coin);

    let reward_coin = coin::zero<RewardCoin>(ctx);

    if (account.amount != 0) {
      let pending_reward = calculate_pending_rewards(
        account, 
        farm.stake_coin_decimal_factor, 
        farm.accrued_rewards_per_share
      );
      let pending_reward = math64::min(pending_reward, balance::value(&farm.balance_reward_coin));
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

    emit(Stake<StakeCoin, RewardCoin> { farm: object::id(farm), stake_amount, reward_amount: coin::value(&reward_coin) });

    reward_coin
  }

  /*
  * @notice Allows a user to unstake his `stake_coin` in the `farm`.
  * 
  * @param farm The {Farm<StakeCoin, RewardCoin>}.  
  * @param account The {Account} associated with the `farm`. 
  * @param amount The amount of {StakeCoin} to remove from the `farm`.     
  * @param c The `sui::clock::Clock` shared object.  
  * @return Coin<StakeCoin>. 
  * @return Coin<RewardCoin>. It gives any pending rewards to the user. 
  *
  * aborts-if:  
  * - `amount` is larger than the `account.amount`. If the user tries to unstake more than he has staked.   
  */
  public fun unstake<StakeCoin, RewardCoin>(
    farm: &mut Farm<StakeCoin, RewardCoin>, 
    account: &mut Account<StakeCoin, RewardCoin>,
    amount: u64,
    c: &Clock,
    ctx: &mut TxContext
  ): (Coin<StakeCoin>, Coin<RewardCoin>) {
    assert!(object::id(farm) == account.farm_id, EInvalidAccount);
    update(farm, clock_timestamp_s(c));

    assert!(account.amount >= amount, EInsufficientStakeAmount);

    let pending_reward = calculate_pending_rewards(
      account, 
      farm.stake_coin_decimal_factor, 
      farm.accrued_rewards_per_share
    );

    let stake_coin = coin::zero<StakeCoin>(ctx);
    let reward_coin = coin::zero<RewardCoin>(ctx);

    if (amount != 0) {
      account.amount = account.amount - amount;
      coin::join(&mut stake_coin, coin::take(&mut farm.balance_stake_coin, amount, ctx));
    };

    if (pending_reward != 0) {
      let pending_reward = math64::min(pending_reward, balance::value(&farm.balance_reward_coin));  
      coin::join(&mut reward_coin, coin::take(&mut farm.balance_reward_coin, pending_reward, ctx));      
    };

    account.reward_debt = calculate_reward_debt(
      account.amount, 
      farm.stake_coin_decimal_factor, 
      farm.accrued_rewards_per_share
    );

    emit(Unstake<StakeCoin, RewardCoin> { farm: object::id(farm), unstake_amount: amount, reward_amount: pending_reward });

    (stake_coin, reward_coin)
  }

  // === Public Destroy Function ===        

  /*
  * @notice Destroys the `account`.
  * 
  * @param account An {Account} associated with a {Farm}. 
  *
  * aborts-if:  
  * - `account` has an amount greater than zero.   
  */
  public fun destroy_zero_account<StakeCoin, RewardCoin>(account: Account<StakeCoin, RewardCoin>) {
    let Account { id, amount, reward_debt: _, farm_id: _ } = account;
    assert!(amount == 0, EAccountHasValue);
    object::delete(id);
  }

  // === Admin Only Functions ===        

  /*
  * @notice Updates the rewards per second of the `farm`.
  * 
  * @param farm The {Farm<StakeCoin, RewardCoin>}.  
  * @param cap The {OwnerCap} that "owns" the `farm`.  
  * @param new_rewards_per_second The new amount of {RewardCoin} the `farm` will give. 
  * @param c The `sui::clock::Clock` shared object.  
  *
  * aborts-if:  
  * - `cap` does not own the `farm`.    
  */
  public fun update_rewards_per_second<StakeCoin, RewardCoin>(
    farm: &mut Farm<StakeCoin, RewardCoin>,     
    cap: &OwnerCap<FarmWitness>, 
    new_rewards_per_second: u64,
    c: &Clock
  ) {
    owner::assert_ownership(cap, object::id(farm));
    update(farm, clock_timestamp_s(c));

    farm.rewards_per_second = new_rewards_per_second;

    emit(NewRewardRate<StakeCoin, RewardCoin> { farm: object::id(farm), rate: new_rewards_per_second });
  }

  /*
  * @notice Destroys the `farm`.
  * 
  * @param farm The {Farm<StakeCoin, RewardCoin>}.  
  * @param cap The {OwnerCap} that "owns" the `farm`.  
  *
  * aborts-if:  
  * - `cap` does not own the `farm`.    
  * - `farm` still has staked coins.  
  * - `farm` still has reward coins. 
  */
  public fun destroy_zero_farm<StakeCoin, RewardCoin>(farm: Farm<StakeCoin, RewardCoin>, cap: &OwnerCap<FarmWitness>) {
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

  /*
  * @notice Returns a mutable reference of the `farm`'s `sui::object::UI to allow the 'cap` owner to extend its functionalities. 
  * 
  * @param farm The {Farm<StakeCoin, RewardCoin>}.  
  * @param cap The {OwnerCap} that "owns" the `farm`.  
  * @return &mut UID. 
  *
  * aborts-if:  
  * - `cap` does not own the `farm`.    
  */
  public fun borrow_mut_uid<StakeCoin, RewardCoin>(farm: &mut Farm<StakeCoin, RewardCoin>, cap: &OwnerCap<FarmWitness>): &mut UID {
    owner::assert_ownership(cap, object::id(farm));
    &mut farm.id    
  }

  // === Private Functions ===       

  /*
  * @notice It converts the timestamp from milliseconds to seconds. 
  *
  * @param c The `sui::clock::Clock` shared object.  
  * @return u64. The timestamp is in seconds. 
  */
  fun clock_timestamp_s(c: &Clock): u64 {
    clock::timestamp_ms(c) / 1000
  }

  /*
  * @notice Updates the `farm` accrued_rewards_per_share to calculate the pending rewards correctly.  
  * 
  * @param farm The {Farm<StakeCoin, RewardCoin>}.  
  * @param now The current timestamp in seconds.     
  */
  fun update<StakeCoin, RewardCoin>(farm: &mut Farm<StakeCoin, RewardCoin>, now: u64) {
    if (farm.last_reward_timestamp >= now || farm.start_timestamp> now) return;

    let total_staked_value = balance::value(&farm.balance_stake_coin);
    
    let prev_reward_time_stamp = farm.last_reward_timestamp;
    farm.last_reward_timestamp = now;

    if (total_staked_value == 0) return;

    let total_reward_value = balance::value(&farm.balance_reward_coin);

    farm.accrued_rewards_per_share = calculate_accrued_rewards_per_share(
      farm.rewards_per_second,
      farm.accrued_rewards_per_share,
      total_staked_value,
      total_reward_value,
      farm.stake_coin_decimal_factor,
      now - prev_reward_time_stamp 
    );
  }

  /*
  * @notice Utility function to calculate the accrued rewards per share of a {Farm}.  
  * 
  * @param rewards_per_second The amount of rewards the farm can give every second.   
  * @param last_accrued_rewards_per_share The last calculated accrued_rewards_per_share of the {Farm}.    
  * @param total_staked_token Total amount of staked coin in the {Farm}.    
  * @param total_reward_value Total amount of reward coin in the {Farm}.  
  * @param stake_factor The decimal scalar of the stake coin.   
  * @param timestamp_delta The decimal scalar of the stake coin.   
  * @return u256. The new {Farm}'s accrued rewards per share.           
  */
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

  /*
  * @notice Utility function calculates the pending rewards of a user.  
  * 
  * @param account An {Account} associated with a {Farm}. 
  * @param stake_factor The decimal scalar of the stake coin.   
  * @param accrued_rewards_per_share The {Farm}'s accrued rewards per share. 
  * @return u256. The pending rewards of a user.            
  */
  fun calculate_pending_rewards<StakeCoin, RewardCoin>(acc: &Account<StakeCoin, RewardCoin>, stake_factor: u64, accrued_rewards_per_share: u256): u64 {
    ((((acc.amount as u256) * accrued_rewards_per_share / (stake_factor as u256)) - acc.reward_debt) as u64)
  }

  /*
  * @notice Utility function to calculate the reward debt of a user.  
  * 
  * @param stake_amount The current stake amount of the user.  
  * @param stake_Factor The decimal scalar of the {StakeCoin}.  
  * @param accrued_rewards_per_share The {Farm}'s accrued rewards per share. 
  * @return u256. The reward debt of the user.            
  */
  fun calculate_reward_debt(stake_amount: u64, stake_factor: u64, accrued_rewards_per_share: u256): u256 {
    let (stake_amount, stake_factor) = (
      (stake_amount as u256),
      (stake_factor as u256)
    );

    (stake_amount * accrued_rewards_per_share) / stake_factor
  }
}