/*
* @title Multi Reward Farm
*
* @notice A contract to distribute multiple reward tokens to stakers. 
*
* @dev All times are in seconds.
*/
module suitears::multi_reward_farm {
  // === Imports ===   

  use std::type_name::{Self, TypeName};

  use sui::math;
  use sui::event::emit;
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::vec_map::{Self, VecMap};
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
  struct MultiRewardFarmWitness has drop {}
  
  struct Account<phantom StakeCoin> has key, store {
    id: UID,
    // The `sui::object::ID` of the farm to which this account belongs to. 
    farm_id: ID,
    // The amount of {StakeCoin} the user has in the {Farm}.  
    amount: u64,
    // `sui::vec_map::VecMap` from Coin `std::type_name::TypeName` to {AccountReward}.  
    rewards_map: VecMap<TypeName, AccountReward>
  }

  struct AccountReward has store {
    // The amount of Reward Coin the user has accrued.
    amount: u64,
    // Amount of rewards the {Farm} has already paid the user.  
    debt: u256
  }

  struct Farm<phantom StakeCoin> has key, store {
    id: UID,
    // Last timestamp that the farm was updated. 
    last_reward_timestamp: u64,
    // {StakeCoin} deposited in this farm. 
    balance_stake_coin: Balance<StakeCoin>,
    // The decimal scalar of the {StakeCoin}.  
    stake_coin_decimal_factor: u64,
    // `sui::vec_map::VecMap` from Coin `std::type_name::TypeName` to {PoolReward}.  
    rewards_map: VecMap<TypeName, PoolReward>,
    // The `sui::object::ID` of the {OwnerCap} that "owns" this farm. 
    owned_by: ID
  }

  struct PoolReward has store {
    // The timestamp in seconds that this farm will start distributing rewards.  
    start_timestamp: u64,
    // Amount of {RewardCoin} to give to stakers per second.  
    rewards_per_second: u64,
    // Total amount of rewards per share distributed by this farm.   
    accrued_rewards_per_share: u256,
  }
}