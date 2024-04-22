/*
* @title Coin Decimals
*
* @notice An object that stores and returns the decimals of a Coin. 
*
* @dev The idea is to pass a single argument `CoinDecimals` to functions that require several `sui::coin::CoinMetadata` objects.
*/
module suitears::coin_decimals {
  // === Imports ===

  use std::type_name::{Self, TypeName};

  use sui::math::pow;
  use sui::dynamic_field as df;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::coin::{Self, CoinMetadata};
  use suitears::owner::{Self, OwnerCap};

  // === Structs ===  

  // @dev To associate the {OwnerCap} with this module. 
  struct CoinDecimalsWitness has drop {}

  struct Decimals has store {
    // Decimals of a `sui::coin` 
    decimals: u8,
    // The scalar of a `sui::coin`'s decimals. It is calculated by 10^decimals.  
    // E.g. `sui::sui` has a scalar of 1_000_000_000 or 1e9. 
    scalar: u64
  }

  struct CoinDecimals has key, store {
    id: UID
  }

  // === Public Create Function ===

  /*
  * @notice It creates an {OwnerCap<CoinDecimalsWitness>}. 
  * It is used to provide admin capabilities to the holder.
  *
  * @return {OwnerCap<CoinDecimalsWitness}. 
  */
  public fun new_cap(ctx: &mut TxContext): OwnerCap<CoinDecimalsWitness> {
    owner::new(CoinDecimalsWitness {}, vector[], ctx)
  }

  /*
  * @notice It creates a new {CoinDecimals}.  
  *
  * @param cap An {OwnerCap<CoinDecimalsWitness>} that will own the new {CoinDecimals}.
  * @return {CoinDecimals}.
  */
  public fun new(cap: &mut OwnerCap<CoinDecimalsWitness>, ctx: &mut TxContext): CoinDecimals {
    let coin_decimals =  CoinDecimals { id: object::new(ctx) };
    owner::add(cap, CoinDecimalsWitness {}, object::id(&coin_decimals));
    coin_decimals
  }

  // === Public View Functions ===

  /*
  * @notice Checks if a coin with type `CoinType` has been added to `self`.
  *
  * @param self A {CoinDecimals} object. 
  * @return bool. True if the coin's decimals and scalar are in the `self`. 
  */
  public fun contains<CoinType>(self: &CoinDecimals): bool {
    df::exists_(&self.id, type_name::get<CoinType>())
  }    

  /*
  * @notice returns the decimals of a coin with the type `CoinType`.
  *
  * @param self A {CoinDecimals} object. 
  * @return u8. The decimals of the coin. 
  *
  * aborts-if 
  * - `CoinType` has not been added to the `self`.
  */
  public fun decimals<CoinType>(self: &CoinDecimals): u8 {
    let data = df::borrow<TypeName, Decimals>(&self.id, type_name::get<CoinType>());
    data.decimals
  }  

  /*
  * @notice returns the decimals scalar of a coin with type `CoinType`.
  *
  * @param self A {CoinDecimals} object. 
  * @return u64. The decimal's scalar. It is calculated by 10^decimals.  
  *
  * aborts-if 
  * - `CoinType` has not been added to the `self`.
  */
  public fun scalar<CoinType>(self: &CoinDecimals): u64 {
    let data = df::borrow<TypeName, Decimals>(&self.id, type_name::get<CoinType>());
    data.scalar
  } 

  // === Public Mutative Function ===  

  /*
  * @notice Adds the decimals and decimal scalar of a coin with type `CoinType` to `self`.
  *
  * @dev It does not abort if it has been added already. 
  *
  * @param self A {CoinDecimals} object. 
  * @param coin_metadata The `sui::coin::CoinMetadata` of a coin with type `CoinType`. 
  */
  public fun add<CoinType>(self: &mut CoinDecimals, coin_metadata: &CoinMetadata<CoinType>) {
    if (contains<CoinType>(self)) return;
    let decimals = coin::get_decimals(coin_metadata);
    df::add(&mut self.id, type_name::get<CoinType>(), Decimals { decimals, scalar: pow(10, decimals) });
  }

  /*
  * @notice Removes the {Decimals} dynamic field and destroys it for `CoinType` from `self`.
  *
  * @param self A {CoinDecimals} object. 
  * @param cap An {OwnerCap<CoinDecimalsWitness>} that owns the `self`.
  *
  * aborts-if:  
  * - `cap` does not own the `self`.    
  */
  public fun remove_and_destroy<CoinType>(self: &mut CoinDecimals, cap: &OwnerCap<CoinDecimalsWitness>) {
    owner::assert_ownership(cap, object::id(self));
    let decimals = df::remove(&mut self.id, type_name::get<CoinType>());
    let Decimals { decimals:  _, scalar: _} = decimals;
  }

  /*
  * @notice Destroys the `self`.
  *
  * @param self A {CoinDecimals} object. 
  * @param cap An {OwnerCap<CoinDecimalsWitness>} that owns the `self`.
  *
  * aborts-if:  
  * - `cap` does not own the `self`.    
  */
  public fun destroy(self: CoinDecimals, cap: &OwnerCap<CoinDecimalsWitness>) {
    owner::assert_ownership(cap, object::id(&self));
    let CoinDecimals { id } = self;
    object::delete(id);
  }
}
