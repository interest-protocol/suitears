module suitears::farm {

  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::tx_context::{Self, TxContext};
  use sui::coin::{Self, Coin, CoinMetadata};
  use sui::object_table::{Self, ObjectTable};

  use suitears::ownership::{Self, OwnershipCap};

  // Errors
  const EInvalidStartTime: u64 = 0;
  const EInvalidEndTime: u64 = 1;
  const ESameCoin: u64 = 2;
  const EPoolLimitZero: u64 = 3;

  struct FarmWitness has drop {}

  struct FarmCap has key, store {
    id: UID,
    cap: OwnershipCap<FarmWitness>,
  }

  struct AccountInfo has key, store {
    id: UID,
    amount: u64,
    reward_debt: u256
  }

  struct Farm<phantom StakeCoin, phantom RewardCoin> has key, store {
    id: UID,
    balance_stake_coin: Balance<StakeCoin>,
    balance_reward_coin: Balance<RewardCoin>,
    accounts: ObjectTable<address, AccountInfo>,
    reward_per_millisecond: u64,
    start_timestamp: u64,
    end_timestamp: u64,
    last_reward_timestamp: u64,
    milliseconds_for_user_limit: u64,
    pool_limit_per_user: u64,
    account_token_per_share: u256,
    stake_coin_decimal_factor: u64,
    reward_coin_decimal_factor: u64
  }

  public fun create_cap(ctx: &mut TxContext): FarmCap {
    FarmCap {
      id: object::new(ctx),
      cap: ownership::create(FarmWitness {}, vector[], ctx)
    }
  }

  public fun create_farm<StakeCoin, RewardCoin>(
    cap: &mut FarmCap,
    stake_coin_metadata: &CoinMetadata<StakeCoin>,
    reward_coin: Coin<RewardCoin>,
    reward_coin_metadata: &CoinMetadata<RewardCoin>,
    c: Clock,
    reward_per_millisecond: u64,
    start_timestamp: u64,
    end_timestamp: u64,
    pool_limit_per_user: u64,
    milliseconds_for_user_limit: u64,
    ctx: &mut TxContext
  ) {

  }

  // @dev Can attach the AccountInfo to the farm and other data
  public fun borrow_mut_uid<StakeCoin, RewardCoin>(cap: &FarmCap, self: &mut Farm<StakeCoin, RewardCoin>): &mut UID {
    ownership::assert_ownership(&cap.cap, object::id(self));
    &mut self.id    
  }
}