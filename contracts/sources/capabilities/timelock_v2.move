module suitears::timelock_v2 {

  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;

  const EInvalidTime: u64 = 0;
  const ETooEarly: u64 = 1;
  const EYouHaveAnObligation: u64 = 2;
  const EYouHaveNoObligation: u64 = 3;

  struct Timelock<T: store> has key, store {
    id: UID,
    timestamp: u64,
    data: T,
    obligation: bool
  }

  // Hot Potatoe to force the data to be locked again
  struct Obligation<phantom T> {
    timestamp: u64
  }

  public fun lock<T: store>(
    c:&Clock, 
    data: T, 
    timestamp: u64, 
    obligation: bool,
    ctx: &mut TxContext
  ): Timelock<T> {
    // It makes no sense to lock in the past
    assert!(timestamp > clock::timestamp_ms(c), EInvalidTime);

    Timelock {
      id: object::new(ctx),
      data,
      timestamp,
      obligation
    }
  }

  public fun view_lock<T: store>(lock: &Timelock<T>): (&T, u64, bool) {
    (&lock.data, lock.timestamp, lock.obligation)
  }

  public fun unlock<T: store>(c:&Clock, lock: Timelock<T>): T {
    assert!(clock::timestamp_ms(c) >= lock.timestamp, ETooEarly);

    let Timelock { data, timestamp: _, id, obligation } = lock;

    assert!(!obligation, EYouHaveAnObligation);

    object::delete(id);

    data
  }

  public fun unlock_with_obligation<T: store>(c:&Clock, lock: Timelock<T>): (T, Obligation<T>) {
    assert!(clock::timestamp_ms(c) >= lock.timestamp, ETooEarly);

    let Timelock { data, timestamp, id, obligation } = lock;

    assert!(obligation, EYouHaveNoObligation);

    object::delete(id);

   (data, Obligation { timestamp })
  }

  public fun relock_with_obligation<T: store>(
    c:&Clock, 
    obligation: Obligation<T>,
    data: T, 
    ctx: &mut TxContext
  ): Timelock<T> {
    let Obligation { timestamp } = obligation;

    Timelock {
      id: object::new(ctx),
      data,
      timestamp: clock::timestamp_ms(c) + timestamp,
      obligation: true
    }
  }
}