module suitears::dao_quest {

  use suitears::atomic_quest::{Self, AtomicQuest};

  struct DaoQuest<phantom DaoOTW> has drop {}

  friend suitears::dao;

  public(friend) fun create_quest<DaoOTW: drop>(): AtomicQuest<DaoQuest<DaoOTW>> {
    atomic_quest::create(DaoQuest {})
  }
}