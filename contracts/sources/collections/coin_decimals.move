// Global Repo for protocols to know a coin decimals
module suitears::coin_decimals {
  use std::type_name::{get, TypeName};

  use sui::math::pow;
  use sui::dynamic_field as df;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::coin::{Self, CoinMetadata};

  struct Decimals has store {
    decimals: u8,
    decimals_scalar: u64
  }

  struct CoinDecimals has key {
    id: UID
  }

  fun init(ctx: &mut TxContext) {
    share_object(CoinDecimals { id: object::new(ctx) });
  }

  public fun register_coin<CoinType>(self: &mut CoinDecimals, coin_metadata: &CoinMetadata<CoinType>) {
    if (is_coin_registered<CoinType>(self)) return;
    let decimals = coin::get_decimals(coin_metadata);
    df::add(&mut self.id, get<CoinType>(), Decimals { decimals, decimals_scalar: pow(10, decimals) });
  }

  public fun get_decimals_scalar<CoinType>(self: &CoinDecimals): u64 {
    let data = df::borrow<TypeName, Decimals>(&self.id, get<CoinType>());
    data.decimals_scalar
  }

  public fun get_decimals<CoinType>(self: &CoinDecimals): u8 {
    let data = df::borrow<TypeName, Decimals>(&self.id, get<CoinType>());
    data.decimals
  }

  public fun is_coin_registered<CoinType>(self: &CoinDecimals): bool {
    df::exists_(&self.id, get<CoinType>())
  }

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }
}
