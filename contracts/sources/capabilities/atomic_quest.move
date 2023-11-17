/*
* An AtomicQuest is a hot potato
* An AtomicQuest can only be completed if all tasks are completed IN ORDER
* To complete a task the function quest::complete_task must be called with the Witness
* Only a quest giver can create quests by passing a Witness
* It is possible to make a Quest with no tasks!
* Each Task may contain a Reward payload
*/
module suitears::atomic_quest {
  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::tx_context::TxContext;
  use sui::object::{Self, UID, ID};
  use sui::vec_set::{Self, VecSet};
  use sui::dynamic_object_field as dfo;
  
  const EWrongTasks: u64 = 0;
  const ETaskHasReward: u64 = 1;
  const ETaskHasNoReward: u64 = 2;

  struct RewardKey has copy, drop, store { task: TypeName }

  struct Task has key, store {
    id: UID,
    name: TypeName,
    has_reward: bool
  }

  struct AtomicQuest<phantom QuestGiver: drop> {
    required_tasks: vector<Task>,
    completed_tasks: VecSet<TypeName>
  }

  public fun task_name(task: &Task): TypeName {
    task.name
  }

  public fun task_has_reward(task: &Task): bool {
    task.has_reward
  }

  public fun create<Witness: drop>(_: Witness): AtomicQuest<Witness> {
    AtomicQuest { required_tasks: vector[], completed_tasks: vec_set::empty()}
  }

  public fun create_task<TaskName: drop>(ctx: &mut TxContext): Task {
    Task {
      id: object::new(ctx),
      name: type_name::get<TaskName>(),
      has_reward: false
    }
  }

  public fun create_task_with_reward<TaskName: drop, Reward: store + key>(reward: Reward, ctx: &mut TxContext): Task {
    let name = type_name::get<TaskName>();
    let task = Task {
      id: object::new(ctx),
      name: type_name::get<TaskName>(),
      has_reward: true
    };

    dfo::add(&mut task.id, RewardKey {task: name }, reward);

    task
  }

  public fun add_task<Witness: drop>(quest: &mut AtomicQuest<Witness>, task: Task) {
    vector::push_back(&mut quest.required_tasks, task);
  }

  public fun get_required_tasks_names<QuestWitness: drop>(quest: &AtomicQuest<QuestWitness>): vector<TypeName> {
    let names = vector[];
    let length = vector::length(&quest.required_tasks);
    let index = 0;

    while (length > index) {

      vector::push_back(&mut names, vector::borrow(&quest.required_tasks, index).name);

      index = index + 1;
    };

    names
  }

  public fun get_completed_tasks<QuestWitness: drop>(quest: &AtomicQuest<QuestWitness>): vector<TypeName> {
    *vec_set::keys(&quest.completed_tasks)
  }

  public fun complete_task<QuestWitness: drop, Task: drop>(_: Task, quest: &mut AtomicQuest<QuestWitness>) {
    let num_of_tasks = vector::length(&quest.required_tasks);
    let task = vector::borrow(&quest.required_tasks, num_of_tasks);

    assert!(!task.has_reward, ETaskHasReward);
    vec_set::insert(&mut quest.completed_tasks, type_name::get<Task>());
  }

  public fun complete_task_with_reward<QuestWitness: drop, Task: drop, Reward: store + key>(_: Task, quest: &mut AtomicQuest<QuestWitness>): Reward {
    let num_of_tasks = vector::length(&quest.required_tasks);
    let task = vector::borrow_mut(&mut quest.required_tasks, num_of_tasks);
    let key = RewardKey { task: type_name::get<Task>() };
    
    assert!(task.has_reward, ETaskHasNoReward);
    vec_set::insert(&mut quest.completed_tasks, type_name::get<Task>());
    dfo::remove(&mut task.id, key)
  }

  public fun finish_quest<QuestWitness: drop>(quest: AtomicQuest<QuestWitness>) {
    let AtomicQuest { required_tasks, completed_tasks } = quest;

    let num_of_tasks = vector::length(&required_tasks);
    let completed_tasks = vec_set::into_keys(completed_tasks);

    let index = 0;
    
    while (num_of_tasks > index) {
      let Task { id, name, has_reward: _ } = vector::remove(&mut required_tasks, 0);

      assert!(name == vector::remove(&mut completed_tasks, 0), EWrongTasks);

      object::delete(id);

      index = index + 1;
    };

    vector::destroy_empty(required_tasks);
    vector::destroy_empty(completed_tasks);
  }

  // @dev It allows the frontend to read the content of a Reward with devInspectTransactionBlock
  #[allow(unused_function)]
  fun task_reward_id<Reward: store + key>(task: &Task): ID {
    assert!(task.has_reward, ETaskHasNoReward);

    let reward = dfo::borrow<RewardKey, Reward>(&task.id, RewardKey { task: task.name });
    object::id(reward)
  }
}
