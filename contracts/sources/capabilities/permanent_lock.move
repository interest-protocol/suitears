module suitears::permanent_lock {

  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;

  const EInvalidTime: u64 = 0;
  const ETooEarly: u64 = 1;

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

    // @dev We do not show the Data because if it is an Admin Capability
  // It would allow the owner to use admin functions while the lock is active!
  public fun start<T: store>(self: &PermanentLock<T>): u64 {
    self.start
  }

  public fun time_delay<T: store>(self: &PermanentLock<T>): u64 {
    self.time_delay
  }

  public fun unlock_time<T: store>(self: &PermanentLock<T>): u64 {
    self.start + self.time_delay
  }

  public fun lock<T: store>(
    data: T,
    c: &Clock,
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

  public fun unlock_temporarily<T: store>(self: PermanentLock<T>, c: &Clock): (T, Temporary<T>) {
    let PermanentLock { data, start, id, time_delay } = self;

    assert!(clock::timestamp_ms(c) >= start + time_delay, ETooEarly);

    object::delete(id);

   (data, Temporary { time_delay })
  }

  public fun relock<T: store>(
    data: T, 
    c: &Clock, 
    temporary: Temporary<T>,
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