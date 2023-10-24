// Global Repo for protocols to know a coin decimals
module suitears::coin_decimals {
  use std::type_name::{get, TypeName};

  use sui::math::pow;
  use sui::dynamic_field as df;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::coin::{Self, CoinMetadata};

  struct Decimals has store, copy, drop {
    decimals: u8,
    decimals_scalar: u64
  }

  struct CoinDecimals has key, store {
    id: UID
  }

  public fun new(ctx: &mut TxContext): CoinDecimals {
    CoinDecimals { id: object::new(ctx) }
  }

  public fun destroy(metada: CoinDecimals) {
    let CoinDecimals { id } = metada;
    object::delete(id);
  }

  public fun register_coin<CoinType>(metadata: &mut CoinDecimals, coin_metadata: &CoinMetadata<CoinType>) {
    if (is_coin_registered<CoinType>(metadata)) return;
    let decimals = coin::get_decimals(coin_metadata);
    df::add(&mut metadata.id, get<CoinType>(), Decimals { decimals, decimals_scalar: pow(10, decimals) });
  }

  public fun get_decimals_scalar<CoinType>(metadata: &CoinDecimals): u64 {
    let data = df::borrow<TypeName, Decimals>(&metadata.id, get<CoinType>());
    data.decimals_scalar
  }

  public fun get_decimals<CoinType>(metadata: &CoinDecimals): u8 {
    let data = df::borrow<TypeName, Decimals>(&metadata.id, get<CoinType>());
    data.decimals
  }

  public fun is_coin_registered<CoinType>(metadata: &CoinDecimals): bool {
    df::exists_(&metadata.id, get<CoinType>())
  }
}