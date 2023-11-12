/*
* Quests can only be completed if all tasks are completed (DO NOT TO BE IN ORDER)
* To complete a task the function quest::complete_task must be called with the Witness
* Only a quest giver can create quests by passing a Witness
* It is NOT possible to make a Quest with no tasks!
*/
module suitears::quest {
  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::vec_set::{Self, VecSet};

  const EQuestMustHaveTasks: u64 = 0;
  const EWrongTasks: u64 = 1;

  struct Quest<phantom QuestGiver: drop, Reward: store> has key, store {
    id: UID,
    completed_tasks: VecSet<TypeName>,
    required_tasks: VecSet<TypeName>,
    reward: Reward,
  }

  public fun create<Witness: drop, Reward: store>(_: Witness, required_tasks: VecSet<TypeName>, reward: Reward, ctx: &mut TxContext): Quest<Witness, Reward> {
    assert!(vec_set::size(&required_tasks) != 0, EQuestMustHaveTasks);
    Quest {
      id: object::new(ctx),
      required_tasks,
      completed_tasks: vec_set::empty(),
      reward
    }
  }

  public fun view_required_tasks<QuestWitness: drop, Reward: store>(quest: &Quest<QuestWitness, Reward>): vector<TypeName> {
    *vec_set::keys(&quest.required_tasks)
  }

  public fun view_completed_tasks<QuestWitness: drop, Reward: store>(quest: &Quest<QuestWitness, Reward>): vector<TypeName> {
    *vec_set::keys(&quest.completed_tasks)
  }

  public fun complete_task<QuestWitness: drop, Reward: store, Task: drop>(_: Task, quest: &mut Quest<QuestWitness, Reward>) {
    vec_set::insert(&mut quest.completed_tasks, type_name::get<Task>());
  }

  public fun finish_quest<QuestWitness: drop, Reward: store>(quest: Quest<QuestWitness, Reward>): Reward {
    let Quest { id, completed_tasks, required_tasks, reward } = quest;

    object::delete(id);

    let num_of_tasks = vec_set::size(&required_tasks);
    let required_tasks = vec_set::into_keys(required_tasks);
    let completed_tasks = vec_set::into_keys(completed_tasks);

    let index = 0;

    while (num_of_tasks > index) {
      let task = *vector::borrow(&required_tasks, index);
      assert!(vector::contains(&completed_tasks, &task), EWrongTasks);
      index = index + 1;
    };


    reward
  }
}