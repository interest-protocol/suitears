module suitears::dao_quest {
  use std::type_name::TypeName;

  use sui::vec_set::VecSet;

  use suitears::atomic_quest::{Self, AtomicQuest};

  struct DaoQuest has drop {}

   friend suitears::dao;

   public(friend) fun create_quest<Reward: store>(required_tasks: VecSet<TypeName>, reward: Reward): AtomicQuest<DaoQuest, Reward> {
    atomic_quest::create(DaoQuest {}, required_tasks, reward)
   }
}