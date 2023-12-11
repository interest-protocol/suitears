/*
* @title Quest
*
* @notice Quests can only be completed if all tasks are completed. 
*
* @dev To complete a task the function quest::complete_task must be called with the Witness
* Only a quest giver can create quests by passing a Witness
* It is NOT possible to make a Quest with no tasks!
*/
module suitears::quest {
  // === Imports ===

  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::vec_set::{Self, VecSet};

  // === Errors ===

  // @dev Thrown if a {Quest<Reward>} is created without tasks
  const EQuestMustHaveTasks: u64 = 0;
  // @dev Thrown if a {Quest<Reward>} is missing a Task Witness or has a wrong Witness. 
  const EWrongTasks: u64 = 1;

  // === Structs ===

  // @dev It wraps a {Reward} that can be redeemed if all `quest.required_tasks` are completed. 
  struct Quest<Reward: store> has key, store {
    id: UID,
    // Stores the Witnesses of all completed tasks
    required_tasks: VecSet<TypeName>,
    // Contains all the Witnesses the Quest must complete to unwrap the {Reward}. 
    completed_tasks: VecSet<TypeName>,
    // An object that will be returned once the Quest has been completed. 
    reward: Reward,
  }

  // === Public Create Function ===  

  /*
  * @notice Creates a {Quest<Reward>} . 
  *
  * @param collection An object with the store ability.
  * @return OwnerCap<AcCollectionWitness>. A capability to {borrow_mut} and {borrow_mut_uid}. 
  * @return AcCollection<C>. The wrapped `collection`.  
  */
  public fun new<Reward: store>(
  required_tasks: VecSet<TypeName>, 
  reward: Reward, 
  ctx: &mut TxContext
  ): Quest<Reward> {
    assert!(vec_set::size(&required_tasks) != 0, EQuestMustHaveTasks);
    Quest { id: object::new(ctx), required_tasks, completed_tasks: vec_set::empty(), reward }
  }

  // === Public View Function ===    

  /*
  * @notice Wraps a `collection` in a `AcCollection<C>` and creates its {OwnerCap}. 
  *
  * @param collection An object with the store ability.
  * @return OwnerCap<AcCollectionWitness>. A capability to {borrow_mut} and {borrow_mut_uid}. 
  * @return AcCollection<C>. The wrapped `collection`.  
  */
  public fun required_tasks<Reward: store>(quest: &Quest<Reward>): vector<TypeName> {
    *vec_set::keys(&quest.required_tasks)
  }

  public fun completed_tasks<Reward: store>(quest: &Quest<Reward>): vector<TypeName> {
    *vec_set::keys(&quest.completed_tasks)
  }

  // === Public Mutative Functions ===      

  public fun add<Reward: store, Task: drop>(_: Task, quest: &mut Quest<Reward>) {
    vec_set::insert(&mut quest.completed_tasks, type_name::get<Task>());
  }

  public fun finish<Reward: store>(quest: Quest<Reward>): Reward {
    let Quest { id, required_tasks, completed_tasks, reward } = quest;

    object::delete(id);

    let num_of_tasks = vec_set::size(&required_tasks);
    let required_tasks = vec_set::into_keys(required_tasks);
    let completed_tasks = vec_set::into_keys(completed_tasks);

    let index = 0;
    while (num_of_tasks > index) {
     let task = vector::borrow(&required_tasks, index);
     assert!(vector::contains(&completed_tasks, task), EWrongTasks);
     index = index + 1;
    };

    reward
   }
}