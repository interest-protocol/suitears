/*
* @title Quest
*
* @notice Quests can only be finished if all tasks are completed. 
*
* @dev To complete a task the function quest::complete must be called with the Witness.   
* Only a quest giver can create quests by passing a Witness. 
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
  * @param required_tasks A vector set of the required tasks to unlock the `reward`. 
  * @param reward An object with the store ability that can be redeemed once all tasks are completed.
  * @return Quest.
  *
  * aborts-if: 
  * - `self.required_tasks` is empty   
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
  * @notice Returns the required tasks of the `self`. 
  *
  * @param self A {Quest}.
  * @return vector<TypeName>. A vector of the required Witness names to complete the quest.   
  */
  public fun required_tasks<Reward: store>(self: &Quest<Reward>): vector<TypeName> {
    *vec_set::keys(&self.required_tasks)
  }

  /*
  * @notice Returns the completed tasks of the `self`. 
  *
  * @param self A {Quest}.
  * @return vector<TypeName>. A vector of the completed Witness names to complete the quest.   
  */
  public fun completed_tasks<Reward: store>(self: &Quest<Reward>): vector<TypeName> {
    *vec_set::keys(&self.completed_tasks)
  }

  // === Public Mutative Functions ===      

  /*
  * @notice Completes a quest by adding the witness `Task` name to the `self.completed_tasks` vector. 
  *
  * @param self A {Quest}.
  * @param _ A witness `Task`.   
  */
  public fun complete<Reward: store, Task: drop>(self: &mut Quest<Reward>, _: Task) {
    vec_set::insert(&mut self.completed_tasks, type_name::get<Task>());
  }

  /*
  * @notice Finishes a quest and returns the `Reward` to the caller. 
  *
  * @param self A {Quest}.
  * @return Reward.   
  *
  * aborts-if
  * - required_tasks do not match the completed_tasks
  */
  public fun finish<Reward: store>(self: Quest<Reward>): Reward {
    let Quest { id, required_tasks, completed_tasks, reward } = self;

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

