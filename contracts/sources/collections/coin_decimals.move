// Global Repo for protocols to know a coin decimals
module suitears::coin_decimals {
  use std::type_name::{Self, TypeName};

  use sui::math::pow;
  use sui::dynamic_field as df;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::coin::{Self, CoinMetadata};

  struct Decimals has store {
    decimals: u8,
    scalar: u64
  }

  struct CoinDecimals has key, store {
    id: UID
  }

  public fun new(ctx: &mut TxContext): CoinDecimals {
    CoinDecimals { id: object::new(ctx) }
  }

  public fun decimals<CoinType>(self: &CoinDecimals): u8 {
    let data = df::borrow<TypeName, Decimals>(&self.id, type_name::get<CoinType>());
    data.decimals
  }  

  public fun scalar<CoinType>(self: &CoinDecimals): u64 {
    let data = df::borrow<TypeName, Decimals>(&self.id, type_name::get<CoinType>());
    data.scalar
  }  

  public fun contains<CoinType>(self: &CoinDecimals): bool {
    df::exists_(&self.id, type_name::get<CoinType>())
  }  

  public fun add<CoinType>(self: &mut CoinDecimals, coin_metadata: &CoinMetadata<CoinType>) {
    if (contains<CoinType>(self)) return;
    let decimals = coin::get_decimals(coin_metadata);
    df::add(&mut self.id, type_name::get<CoinType>(), Decimals { decimals, scalar: pow(10, decimals) });
  }
}
