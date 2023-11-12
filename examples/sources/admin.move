/*
* This module allows anyone to create an AdminCap with a shared AdminStorage to manage access to their dApps
* It has safe mechanisms against several attack vectors by requiring a two-step transfer and an epoch delay before transferring
*/
module suitears::admin {
  
  use sui::transfer;
  use sui::event::emit;
  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID, ID};
  use sui::types::is_one_time_witness;
  use sui::tx_context::{Self, TxContext};

  use suitears::timelock::{Self, TimeLockCap};

  // Errors
  const EZeroAddress: u64 = 0;
  const EInvalidAcceptSender: u64 = 1;
  const EAdminDidNotAccept: u64 = 2;
  const EInvalidWitness: u64 = 5;
  const EInvalidTimeLock: u64 = 6;

  // Do not expose this
  struct TimeLockName has drop {}

  struct PendingAdmin has copy, drop, store {}

  // The owner of this object can add and remove minters + update the metadata
  struct AdminCap<phantom T: drop> has key {
    id: UID
  }

  struct AdminStorage<phantom T: drop> has key {
    id: UID,
    pending_admin: address,
    current_admin: address,
    accepted: bool,
    time_delay: u64
  }

  // * Events

  struct Create<phantom T> has copy, drop {
    storage_id: ID,
    cap_id: ID,
    sender: address,
    time_delay: u64
  }

  struct StartTransfer<phantom T> has copy, drop {
    current_admin: address,
    pending_admin: address,
    unlock_timestamp: u64,
    timelock_id: ID,
  }

  struct AcceptTransfer<phantom T> has copy, drop {
    current_admin: address,
    pending_admin: address
  }

  struct CancelTransfer<phantom T> has copy,drop {
    current_admin: address,
  }

  struct NewAdmin<phantom T> has copy, drop {
    admin: address
  }

  public fun create<T: drop>(witness: T, time_delay: u64, ctx: &mut TxContext): (AdminStorage<T>, AdminCap<T>) {
    assert!(is_one_time_witness(&witness), EInvalidWitness);
    let sender = tx_context::sender(ctx);

    let admin_cap = AdminCap<T> { id: object::new(ctx) };
    let admin_storage = AdminStorage<T> {
        id: object::new(ctx),
        pending_admin: @0x0,
        current_admin: sender,
        accepted: false,
        time_delay
    };

    emit(Create<T> { 
      sender, 
      storage_id: object::id(&admin_storage), 
      cap_id: object::id(&admin_cap),
      time_delay
    });

    (admin_storage, admin_cap)
  }

  /**
  * @dev It initiates the transfer process of the AdminCap
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun start_transfer<T: drop>(_: &AdminCap<T>, storage: &mut AdminStorage<T>, c: &Clock, recipient: address, ctx: &mut TxContext): TimeLockCap<TimeLockName> {
    assert!(recipient != @0x0, EZeroAddress);
    storage.pending_admin = recipient;
    storage.accepted = false;

    let unlock_timestamp = clock::timestamp_ms(c) + storage.time_delay;
    
    let cap = timelock::create(TimeLockName {}, c, unlock_timestamp,  false, ctx);

    add_pending_admin(&mut cap, recipient);

    emit(StartTransfer<T> {
      current_admin: storage.current_admin,
      pending_admin: recipient,
      timelock_id: object::id(&cap),
      unlock_timestamp 
    });

    cap
  } 

  /**
  * @dev It cancels the transfer of the Admin Cap
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun cancel_transfer<T: drop>(_: &AdminCap<T>, storage: &mut AdminStorage<T>, lock: TimeLockCap<TimeLockName>) {
    storage.pending_admin = @0x0;
    storage.accepted = false;
    timelock::destroy(lock);

    emit(CancelTransfer<T> {
      current_admin: storage.current_admin
    });
  } 

  /**
  * @dev It allows the pending admin to accept the {AdminCap}
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun accept_transfer<T: drop>(storage: &mut AdminStorage<T>, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == storage.pending_admin, EInvalidAcceptSender);

    storage.accepted = true;

    emit(AcceptTransfer<T> {
      current_admin: storage.current_admin,
      pending_admin: storage.pending_admin,
    });
  } 

  /**
  * @dev It transfers the {AdminCap} to the pending admin
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun transfer<T: drop>(cap: AdminCap<T>, c: &Clock, lock: TimeLockCap<TimeLockName>, storage: &mut AdminStorage<T>) {
    // New admin must accept the capability
    assert!(storage.accepted, EAdminDidNotAccept);
    assert!(get_admin(&lock) == storage.pending_admin, EInvalidTimeLock);

    // Will throw if the epoch is not valid
    timelock::assert_unlock_epoch_and_destroy(TimeLockName {}, c, lock);

    storage.accepted = false;
    let new_admin = storage.pending_admin;
    storage.current_admin = new_admin;
    storage.pending_admin = @0x0;

    transfer::transfer(cap, new_admin);

    emit(NewAdmin<T> { admin: new_admin });
  } 

  // Careful, this cannot be reverted
  public fun destroy<T: drop>(cap: AdminCap<T>) {
    let AdminCap { id } = cap;
    object::delete(id);
  }


  // Private Fns

  fun add_pending_admin(lock: &mut TimeLockCap<TimeLockName>, admin: address) {
    timelock::add_extra_data(lock, PendingAdmin {}, admin);
  }

  fun get_admin(lock: &TimeLockCap<TimeLockName>): address {
    *timelock::borrow_extra_data(lock, PendingAdmin {})
  }
}