/*
* An Example on how to implement a TimeLocked Two Step
*/
module examples::admin {
  
  use sui::transfer;
  use sui::event::emit;
  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID, ID};
  use sui::types::is_one_time_witness;
  use sui::tx_context::{Self, TxContext};


  // Errors
  const EZeroAddress: u64 = 0;
  const EInvalidAcceptSender: u64 = 1;
  const EAdminDidNotAccept: u64 = 2;
  const EInvalidWitness: u64 = 3;
  const ETooEarly: u64 = 4;

  const SENTINAL_VALUE: u64 = 18446744073709551615;

  // The owner of this object can add and remove minters + update the metadata
  // * important NO store key, so it cannot be transferred
  struct AdminCap<phantom T: drop> has key {
    id: UID
  }

  struct AdminStorage<phantom T: drop> has key, store {
    id: UID,
    pending_admin: address,
    accepted: bool,
    time_delay: u64,
    start: u64
  }

  // * Events

  struct Create<phantom T> has copy, drop {
    sender: address,
    time_delay: u64,
    start: u64
  }

  struct StartTransfer has copy, drop {
    pending_admin: address
  }

  struct AcceptTransfer<phantom T> has copy, drop {
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
        accepted: false,
        time_delay,
        start: SENTINAL_VALUE
    };

    emit(Create<T> { 
      sender, 
      time_delay,
      start: SENTINAL_VALUE
    });

    (admin_storage, admin_cap)
  }

  /**
  * @dev It initiates the transfer process of the AdminCap
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun start_transfer<T: drop>(_: &AdminCap<T>, storage: &mut AdminStorage<T>, recipient: address) {
    assert!(recipient != @0x0, EZeroAddress);
    storage.pending_admin = recipient;
    storage.accepted = false;
  

    emit(StartTransfer {
      pending_admin: recipient,
    });
  } 

  /**
  * @dev It cancels the transfer of the Admin Cap
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun cancel_transfer<T: drop>(_: &AdminCap<T>, storage: &mut AdminStorage<T>, ctx: &mut TxContext) {
    storage.pending_admin = @0x0;
    storage.accepted = false;
    storage.start = SENTINAL_VALUE;

    emit(CancelTransfer<T> {
      current_admin: tx_context::sender(ctx)
    });
  } 

  /**
  * @dev It allows the pending admin to accept the {AdminCap}
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun accept_transfer<T: drop>(c: &Clock, storage: &mut AdminStorage<T>, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == storage.pending_admin, EInvalidAcceptSender);

    storage.accepted = true;
    storage.start = clock::timestamp_ms(c);

    emit(AcceptTransfer<T> {
      pending_admin: storage.pending_admin,
    });
  } 

  /**
  * @dev It transfers the {AdminCap} to the pending admin
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun transfer<T: drop>(cap: AdminCap<T>, c: &Clock, storage: &mut AdminStorage<T>) {
    // New admin must accept the capability
    assert!(storage.accepted, EAdminDidNotAccept);
    let now = clock::timestamp_ms(c);
    assert!(now >= storage.start + storage.time_delay, ETooEarly);

    storage.accepted = false;
    let new_admin = storage.pending_admin;
    storage.pending_admin = @0x0;
    storage.start = SENTINAL_VALUE;

    transfer::transfer(cap,new_admin);

    emit(NewAdmin<T> { admin: new_admin });
  } 

  // Careful, this cannot be reverted
  public fun destroy_cap<T: drop>(cap: AdminCap<T>) {
    let AdminCap { id } = cap;
    object::delete(id);
  }

  // Careful, this cannot be reverted
  public fun destroy_storage<T: drop>(storage: AdminStorage<T>) {
    let AdminStorage { id, time_delay: _, accepted: _, pending_admin: _, start: _ } = storage;
    object::delete(id);
  }
}