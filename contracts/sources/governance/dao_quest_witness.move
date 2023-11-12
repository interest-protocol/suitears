module suitears::dao_quest_witness {
  use std::type_name::TypeName;

  use sui::vec_set::VecSet;

  use suitears::quest::{Self, Quest};

  struct DaoQuest has drop {}

   friend suitears::dao;

   public(friend) fun create_quest<Reward: store>(required_tasks: VecSet<TypeName>, reward: Reward): Quest<DaoQuest, Reward> {
    quest::create(DaoQuest {}, required_tasks, reward)
   }
}