module suitears::dao_quest {

  use sui::tx_context::TxContext;

  use suitears::atomic_quest::{Self, AtomicQuest};

  struct DaoQuest<phantom DaoOTW> has drop {}

  friend suitears::dao;

  public(friend) fun create_quest<DaoOTW: drop>(ctx: &mut TxContext): AtomicQuest<DaoQuest<DaoOTW>> {
    atomic_quest::create(DaoQuest {}, ctx)
  }
}