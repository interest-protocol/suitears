// it abstracts the Timelock Logic
module suitears::timelock {
    
  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;

  const EWrongPackage: u64 = 0;
  const ETooEarly: u64 = 1;
  const EInvalidTimestamp: u64 = 2;
  const EInvalidOperation: u64 = 3;

  struct TimeLockCap has key, store {
    id: UID,
    unlock_timestamp: u64,
    can_update_unlock_timestamp: bool,
    name: TypeName,
  }

  public fun create<T: drop>(_: T, c: &Clock, unlock_timestamp: u64, can_update_unlock_timestamp: bool, ctx: &mut TxContext): TimeLockCap {
    assert!(unlock_timestamp > clock::timestamp_ms(c), EInvalidTimestamp);

    TimeLockCap {
      id: object::new(ctx),
      unlock_timestamp,
      can_update_unlock_timestamp,
      name: type_name::get<T>()
    }
  }

  // @dev This does not make any assertion. It is only to get a gas rebate
  public fun destroy(timelock: TimeLockCap) {
    let TimeLockCap { id, unlock_timestamp: _, can_update_unlock_timestamp: _, name: _ } = timelock;
    object::delete(id);
  }

  public fun assert_unlock_epoch_and_destroy<T: drop>(_: T, c: &Clock, timelock: TimeLockCap) {
    assert!(clock::timestamp_ms(c) >= timelock.unlock_timestamp, ETooEarly);
    let TimeLockCap { id, unlock_timestamp: _, can_update_unlock_timestamp: _, name } = timelock;
    assert!(name == type_name::get<T>(), EWrongPackage);
    object::delete(id);
  } 

  public fun update_unlock_timestamp<T: drop>(_: T, timelock: &mut TimeLockCap, unlock_epoch: u64) {
    assert!(timelock.can_update_unlock_timestamp, EInvalidOperation);
    timelock.unlock_timestamp = unlock_epoch;
  }

  public fun add_extra_data<Key: store + drop + copy, T: store>(timelock: &mut TimeLockCap, key: Key, data: T) {
   df::add(&mut timelock.id, key, data);
  }

  public fun borrow_extra_data<Key: store + drop + copy, T: store>(timelock: &TimeLockCap, key: Key): &T {
   df::borrow(&timelock.id, key)
  }

  public fun unlock_timestamp(timelock: &TimeLockCap): u64 {
    timelock.unlock_timestamp
  }

  public fun can_update_unlock_timestamp(timelock: &TimeLockCap): bool {
    timelock.can_update_unlock_timestamp
  }
}