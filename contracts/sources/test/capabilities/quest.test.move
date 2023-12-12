#[test_only]
module suitears::quest_tests {
  use std::type_name;
  
  use sui::vec_set;
  use sui::tx_context;
  use sui::test_utils::assert_eq;

  use suitears::quest;
  use suitears::task_one;
  use suitears::task_two;

  struct Reward has store, drop {
    value: u64
  }

  #[test]
  fun test_success_case() {
    let ctx = tx_context::dummy();

    let required_tasks = vec_set::empty();

    vec_set::insert(&mut required_tasks, type_name::get<task_one::Witness>());
    vec_set::insert(&mut required_tasks, type_name::get<task_two::Witness>());

    let q = quest::new(required_tasks, Reward { value: 7}, &mut ctx);

    assert_eq(quest::required_tasks(&q), vector[type_name::get<task_one::Witness>(), type_name::get<task_two::Witness>()]);
    assert_eq(quest::completed_tasks(&q), vector[]);

    task_one::complete_task(&mut q);

    assert_eq(quest::completed_tasks(&q), vector[type_name::get<task_one::Witness>()]);

    task_two::complete_task(&mut q);

    assert_eq(quest::completed_tasks(&q), vector[type_name::get<task_one::Witness>(), type_name::get<task_two::Witness>()]);

    let reward = quest::finish(q);

    assert_eq(reward.value, 7);
  }

  #[test]
  #[expected_failure(abort_code = quest::EQuestMustHaveTasks)]
  fun test_empty_quest() {
    let ctx = tx_context::dummy();

    let required_tasks = vec_set::empty();

    let q = quest::new(required_tasks, Reward { value: 7}, &mut ctx);

    quest::finish(q); 
  }  

  #[test]
  #[expected_failure(abort_code = quest::EWrongTasks)]
  fun test_wrong_tasks() {
    let ctx = tx_context::dummy();

    let required_tasks = vec_set::empty();

    vec_set::insert(&mut required_tasks, type_name::get<task_one::Witness>());
    vec_set::insert(&mut required_tasks, type_name::get<task_two::Witness>());

    let q = quest::new(required_tasks, Reward { value: 7}, &mut ctx);

    task_one::complete_task(&mut q);

    quest::finish(q);
  }   
}


#[test_only]
module suitears::task_one {
  
  use suitears::quest::{Self, Quest};

  struct Witness has drop {}

  public fun complete_task<Reward: store>(self: &mut Quest<Reward>) {
    quest::complete(self, Witness{});
  }
}

#[test_only]
module suitears::task_two {
  
  use suitears::quest::{Self, Quest};

  struct Witness has drop {}

  public fun complete_task<Reward: store>(self: &mut Quest<Reward>) {
    quest::complete(self, Witness{});
  }
}