// it abstracts the Timelock Logic
module suimate::timelock {
    
  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::tx_context::{Self, TxContext};

  const ENotAllowed: u64 = 0;
  const ETooEarly: u64 = 1;
  const EInvalidEpoch: u64 = 2;
  const EInvalidOperation: u64 = 3;
  const EWrongPackage: u64 = 4;

  struct TimeLockCap has key, store {
    id: UID,
    unlock_epoch: u64,
    can_update_unlock_epoch: bool,
    name: TypeName
  }

  public fun create<T: drop>(_: T, unlock_epoch: u64, can_update_unlock_epoch: bool, ctx: &mut TxContext): TimeLockCap {
    assert!(unlock_epoch > tx_context::epoch(ctx), EInvalidEpoch);

    TimeLockCap {
      id: object::new(ctx),
      unlock_epoch,
      can_update_unlock_epoch,
      name: type_name::get<T>()
    }
  }

  // @dev This does not make any assertion. It is only to get a gas rebate
  public fun destroy(timelock: TimeLockCap) {
    let TimeLockCap { id, unlock_epoch: _, can_update_unlock_epoch: _, name: _ } = timelock;
    object::delete(id);
  }

  public fun assert_unlock_epoch_and_destroy<T: drop>(_: T, timelock: TimeLockCap, ctx: &mut TxContext) {
    assert!(tx_context::epoch(ctx) >= timelock.unlock_epoch, ETooEarly);
    let TimeLockCap { id, unlock_epoch: _, can_update_unlock_epoch: _, name } = timelock;
    assert!(name == type_name::get<T>(), EWrongPackage);
    object::delete(id);
  } 

  public fun update_unlock_epoch<T>(timelock: &mut TimeLockCap, unlock_epoch: u64) {
    assert!(timelock.can_update_unlock_epoch, EInvalidOperation);
    timelock.unlock_epoch = unlock_epoch;
  }

  public fun add_extra_data<Key: store + drop + copy, T: store>(timelock: &mut TimeLockCap, key: Key, data: T) {
   df::add(&mut timelock.id, key, data);
  }

  public fun borrow_extra_data<Key: store + drop + copy, T: store>(timelock: &TimeLockCap, key: Key): &T {
   df::borrow(&timelock.id, key)
  }

  public fun unlock_epoch(timelock: &TimeLockCap): u64 {
    timelock.unlock_epoch
  }

  public fun can_update_unlock_epoch(timelock: &TimeLockCap): bool {
    timelock.can_update_unlock_epoch
  }
}