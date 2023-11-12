module suitears::timelock {

  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;

  const EInvalidTime: u64 = 0;
  const ETooEarly: u64 = 1;
  const EYouMustRelock: u64 = 2;
  const EYouCannotUnlockTemporarly: u64 = 3;

  struct Timelock<T: store> has key, store {
    id: UID,
    timestamp: u64,
    data: T,
    permanent: bool
  }

  // Hot Potatoe to force the data to be locked again
  struct Temporary<phantom T> {
    timestamp: u64
  }

  public fun lock<T: store>(
    c:&Clock, 
    data: T, 
    timestamp: u64, 
    permanent: bool, // @dev Careful this makes the capability forever locked
    ctx: &mut TxContext
  ): Timelock<T> {
    // It makes no sense to lock in the past
    assert!(timestamp > clock::timestamp_ms(c), EInvalidTime);

    Timelock {
      id: object::new(ctx),
      data,
      timestamp,
      permanent
    }
  }

  // @dev We do not show the Data because if it is an Admin Capability
  // It would allow the owner to use admin functions while the lock is active!
  public fun view_lock<T: store>(lock: &Timelock<T>): (u64, bool) {
    (lock.timestamp, lock.permanent)
  }

  public fun unlock<T: store>(c:&Clock, lock: Timelock<T>): T {
    assert!(clock::timestamp_ms(c) >= lock.timestamp, ETooEarly);

    let Timelock { data, timestamp: _, id, permanent } = lock;

    assert!(!permanent, EYouMustRelock);

    object::delete(id);

    data
  }

  public fun unlock_temporarily<T: store>(c:&Clock, lock: Timelock<T>): (T, Temporary<T>) {
    assert!(clock::timestamp_ms(c) >= lock.timestamp, ETooEarly);

    let Timelock { data, timestamp, id, permanent } = lock;

    assert!(permanent, EYouCannotUnlockTemporarly);

    object::delete(id);

   (data, Temporary { timestamp })
  }

  public fun relock_permanently<T: store>(
    c:&Clock, 
    temporary: Temporary<T>,
    data: T, 
    ctx: &mut TxContext
  ): Timelock<T> {
    let Temporary { timestamp } = temporary;

    Timelock {
      id: object::new(ctx),
      data,
      timestamp: clock::timestamp_ms(c) + timestamp,
      permanent: true
    }
  }
}