/*
* @title Dao Admin
*
* @notice It creates a capability to enable Daos to update their settings and interact with the treasury. 
*/
module suitears::dao_admin { 
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  // === Friends ===

  friend suitears::dao;

  // === Struct ===

  struct DaoAdmin<phantom OTW: drop> has key, store {
    id: UID
  }

  /*
  * @notice Creates a {DaoAdmin<OTW>}
  *
  * @return DaoAdmin
  */
  public(friend) fun new<OTW: drop>(ctx: &mut TxContext): DaoAdmin<OTW> {
    DaoAdmin {
      id: object::new(ctx)
    }
  }
 }