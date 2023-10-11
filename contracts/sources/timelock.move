// it abstracts the Timelock Logic
module suimate::timelock {

  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};

  const ENotAllowed: u64 = 0;
  const ETooEarly: u64 = 1;
  const EInvalidEpoch: u64 = 2;

  struct TimeLock<phantom T> has key, store {
    id: UID,
    allow_extensions: bool,
    unlock_epoch: u64
  }

  public fun create<T: drop>(_: T, unlock_epoch: u64, allow_extensions: bool, ctx: &mut TxContext): TimeLock<T> {
    assert!(unlock_epoch > tx_context::epoch(ctx), EInvalidEpoch);

    TimeLock<T> {
      id: object::new(ctx),
      allow_extensions,
      unlock_epoch
    }
  }

  public fun destroy<T: drop>(timelock: TimeLock<T>) {
    let TimeLock { id, allow_extensions: _, unlock_epoch: _ } = timelock;
    object::delete(id);
  } 

  public fun unlock<T: drop>(timelock: TimeLock<T>, ctx: &mut TxContext) {
    assert!(tx_context::epoch(ctx) >= timelock.unlock_epoch, ETooEarly);
    destroy(timelock);
  }

  public fun uid<T: drop>(self: &TimeLock<T>): &UID {
    &self.id
  }

  public fun uid_mut<T: drop>(self: &mut TimeLock<T>): &mut UID {
    assert!(self.allow_extensions, ENotAllowed);
    &mut self.id
  } 
}