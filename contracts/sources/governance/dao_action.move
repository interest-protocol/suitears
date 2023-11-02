module suitears::dao_action {

  friend suitears::dao;

  // Hot Potato do not add abilities
  struct Action<phantom DaoWitness: drop, phantom ModuleWitness: drop, phantom CoinType, T: store> {
    payload: T
  }

  public(friend) fun create<DaoWitness: drop, ModuleWitness: drop, CoinType, T: store>(payload: T): Action<DaoWitness, ModuleWitness, CoinType, T> {
    Action {
      payload
    }
  }

  public fun finish_action<DaoWitness: drop, ModuleWitness: drop, CoinType, T: store>(_: ModuleWitness, action: Action<DaoWitness, ModuleWitness, CoinType, T>): T {
    let Action { payload } = action;
    payload
  }
}