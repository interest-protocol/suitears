module suitears::dao_action {
  use std::vector;
  use std::type_name::{get, TypeName};

  use sui::vec_set::{Self, VecSet};

  const EInvalidRules: u64 = 0;

  friend suitears::dao;

  // Hot Potato do not add abilities
  struct Action<phantom DaoWitness: drop, phantom CoinType, T: store> {
    payload: T,
    rules: VecSet<TypeName>,
    completed: VecSet<TypeName>
  }

  public(friend) fun create<DaoWitness: drop, CoinType, T: store>(rules: VecSet<TypeName>, payload: T): Action<DaoWitness, CoinType, T> {
    Action {
      payload,
      rules,
      completed: vec_set::empty()
    }
  }

  public fun complete_rule<DaoWitness: drop, CoinType, T: store, Rule: drop>(_: Rule, action: &mut Action<DaoWitness, CoinType, T>) {
    vec_set::insert(&mut action.completed, get<Rule>());
  }

  public fun finish_action<DaoWitness: drop, CoinType, T: store>(action: Action<DaoWitness, CoinType, T>): T {
    let Action { payload, rules, completed } = action;
    let rules_size = vec_set::size(&rules);
    assert!(rules_size == vec_set::size(&completed), EInvalidRules);

    let rules = vec_set::into_keys(rules);
    let index = 0;
    
    while (rules_size > index) {
      let rule = *vector::borrow(&rules, index);
      assert!(vec_set::contains(&completed, &rule), EInvalidRules);
      index = index + 1;
    };

    payload
  }
}