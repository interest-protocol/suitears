/*
* An AtomicQuest is a hot potato
* Quests can only be completed if all tasks are completed IN ORDER
* To complete a task the function quest::complete_task must be called with the Witness
* Only a quest giver can create quests by passing a Witness
* It is possible to make a Quest with no tasks!
*/
module suitears::atomic_quest {
  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::vec_set::{Self, VecSet};

  const EWrongTasks: u64 = 0;

  struct AtomicQuest<phantom QuestGiver: drop, Reward: store> {
    required_tasks: VecSet<TypeName>,
    completed_tasks: VecSet<TypeName>,
    reward: Reward,
  }

  public fun create<Witness: drop, Reward: store>(_: Witness, required_tasks: VecSet<TypeName>, reward: Reward): AtomicQuest<Witness, Reward> {
    AtomicQuest { required_tasks, completed_tasks: vec_set::empty(), reward }
  }

  public fun get_required_tasks<QuestWitness: drop, Reward: store>(quest: &AtomicQuest<QuestWitness, Reward>): vector<TypeName> {
    *vec_set::keys(&quest.required_tasks)
  }

  public fun get_completed_tasks<QuestWitness: drop, Reward: store>(quest: &AtomicQuest<QuestWitness, Reward>): vector<TypeName> {
    *vec_set::keys(&quest.completed_tasks)
  }

  public fun complete_task<QuestWitness: drop, Reward: store, Task: drop>(_: Task, quest: &mut AtomicQuest<QuestWitness, Reward>) {
    vec_set::insert(&mut quest.completed_tasks, type_name::get<Task>());
  }

  public fun finish_quest<QuestWitness: drop, Reward: store>(quest: AtomicQuest<QuestWitness, Reward>): Reward {
    let AtomicQuest { required_tasks, completed_tasks, reward } = quest;

    let num_of_tasks = vec_set::size(&required_tasks);
    let required_tasks = vec_set::into_keys(required_tasks);
    let completed_tasks = vec_set::into_keys(completed_tasks);

    let index = 0;
    while (num_of_tasks > index) {
      assert!(vector::borrow(&required_tasks, index) == vector::borrow(&completed_tasks, index), EWrongTasks);
      index = index + 1;
    };

    reward
  }
}