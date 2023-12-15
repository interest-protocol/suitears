module suitears::dao_admin { 

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  friend suitears::dao;

  struct DaoAdmin<phantom OTW: drop> has key, store {
    id: UID
  }

  public(friend) fun new<OTW: drop>(ctx: &mut TxContext): DaoAdmin<OTW> {
    DaoAdmin {
      id: object::new(ctx)
    }
  }
 }