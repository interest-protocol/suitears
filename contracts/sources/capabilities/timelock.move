module suitears::timelock {

  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;

  const EInvalidTime: u64 = 0;
  const ETooEarly: u64 = 1;

  struct Timelock<T: store> has key, store {
    id: UID,
    unlock_time: u64,
    data: T,
  }

  struct PermanentLock<T: store> has key, store {
    id: UID,
    start: u64,
    data: T,
    time_delay: u64
  }

  // Hot Potatoe to force the data to be locked again
  struct Temporary<phantom T> {
    time_delay: u64, 
  }

  public fun lock<T: store>(
    c:&Clock,
    data: T, 
    unlock_time: u64,
    ctx: &mut TxContext
  ): Timelock<T> {
    // It makes no sense to lock in the past
    assert!(unlock_time > clock::timestamp_ms(c), EInvalidTime);

    Timelock {
      id: object::new(ctx),
      data,
      unlock_time
    }
  }

  public fun lock_permanently<T: store>(
    c:&Clock,
    data: T,
    time_delay: u64,
    ctx: &mut TxContext
  ): PermanentLock<T> {
    // It makes no sense to lock in the past
    assert!(time_delay != 0, EInvalidTime);

    PermanentLock {
      id: object::new(ctx),
      data,
      start: clock::timestamp_ms(c),
      time_delay
    }
  }

  // @dev We do not show the Data because if it is an Admin Capability
  // It would allow the owner to use admin functions while the lock is active!
  public fun view_lock<T: store>(lock: &Timelock<T>): u64 {
    lock.unlock_time
  }

    // @dev We do not show the Data because if it is an Admin Capability
  // It would allow the owner to use admin functions while the lock is active!
  public fun view_permanent_lock<T: store>(lock: &PermanentLock<T>): u64 {
    lock.start + lock.time_delay
  }

  public fun unlock<T: store>(c:&Clock, lock: Timelock<T>): T {
    assert!(clock::timestamp_ms(c) >= lock.unlock_time, ETooEarly);

    let Timelock { data, unlock_time: _, id } = lock;

    object::delete(id);

    data
  }

  public fun unlock_temporarily<T: store>(c:&Clock, lock: PermanentLock<T>): (T, Temporary<T>) {
    assert!(clock::timestamp_ms(c) >= lock.start + lock.time_delay, ETooEarly);

    let PermanentLock { data, start: _, id, time_delay } = lock;

    object::delete(id);

   (data, Temporary { time_delay })
  }

  public fun relock_permanently<T: store>(
    c:&Clock, 
    temporary: Temporary<T>,
    data: T, 
    ctx: &mut TxContext
  ): PermanentLock<T> {
    let Temporary { time_delay } = temporary;

    PermanentLock {
      id: object::new(ctx),
      data,
      start: clock::timestamp_ms(c),
      time_delay
    }
  }
}