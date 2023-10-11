/*
* This module allows anyone to create an AdminCap with a shared AdminStorage to manage access to their dApps
* It has safe mechanisms against several attack vectors by requiring a two-step transfer and an epoch delay before transferring
*/
module suimate::admin {
  
  use sui::transfer;
  use sui::event::emit;
  use sui::object::{Self, UID, ID};
  use sui::types::is_one_time_witness;
  use sui::tx_context::{Self, TxContext};

  const SENTINEL_VALUE: u64 = 18446744073709551615;

  // Errors
  const EZeroAddress: u64 = 0;
  const EInvalidAcceptSender: u64 = 1;
  const EAdminDidNotAccept: u64 = 2;
  const ETooEarly: u64 = 4;
  const EInvalidWitness: u64 = 5;

  // The owner of this object can add and remove minters + update the metadata
  struct AdminCap<phantom T> has key {
    id: UID
  }

  struct AdminStorage<phantom T> has key {
    id: UID,
    pending_admin: address,
    current_admin: address,
    accepted: bool,
    init_transfer_epoch: u64,
    epochs_delay: u64
  }

  // * Events

  struct Create<phantom T> has copy, drop {
    storage_id: ID,
    cap_id: ID,
    epochs_delay: u64,
    sender: address
  }

  struct StartTransfer<phantom T> has copy, drop {
    current_admin: address,
    pending_admin: address
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

  public fun create<T: drop>(witness: T, epochs_delay: u64, ctx: &mut TxContext): AdminCap<T> {
    assert!(is_one_time_witness(&witness), EInvalidWitness);
    let sender = tx_context::sender(ctx);

    let admin_cap = AdminCap<T> { id: object::new(ctx) };
    let admin_storage = AdminStorage<T> {
        id: object::new(ctx),
        pending_admin: @0x0,
        current_admin: sender,
        accepted: false,
        init_transfer_epoch: SENTINEL_VALUE,
        epochs_delay
    };

    emit(Create<T> { 
      sender, 
      storage_id: object::id(&admin_storage), 
      cap_id: object::id(&admin_cap),
      epochs_delay
    });

    transfer::share_object(admin_storage);

    admin_cap
  }

  /**
  * @dev It initiates the transfer process of the AdminCap
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun start_transfer<T>(_: &AdminCap<T>, storage: &mut AdminStorage<T>, recipient: address, ctx: &mut TxContext) {
    assert!(recipient != @0x0, EZeroAddress);
    storage.pending_admin = recipient;
    storage.accepted = false;
    storage.init_transfer_epoch = tx_context::epoch(ctx);

    emit(StartTransfer<T> {
      current_admin: storage.current_admin,
      pending_admin: recipient
    });
  } 

  /**
  * @dev It cancels the transfer of the Admin Cap
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  entry public fun cancel_transfer<T>(_: &AdminCap<T>, storage: &mut AdminStorage<T>) {
    storage.pending_admin = @0x0;
    storage.accepted = false;
    storage.init_transfer_epoch = SENTINEL_VALUE;

    emit(CancelTransfer<T> {
      current_admin: storage.current_admin
    });
  } 

  /**
  * @dev It allows the pending admin to accept the {AdminCap}
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  entry public fun accept_transfer<T>(storage: &mut AdminStorage<T>, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == storage.pending_admin, EInvalidAcceptSender);
    storage.accepted = true;

    emit(AcceptTransfer<T> {
      current_admin: storage.current_admin,
      pending_admin: storage.pending_admin
    });
  } 

  /**
  * @dev It transfers the {AdminCap} to the pending admin
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  public fun transfer<T>(cap: AdminCap<T>, storage: &mut AdminStorage<T>, ctx: &mut TxContext) {
    // New admin must accept the capability
    assert!(storage.accepted, EAdminDidNotAccept);
    assert!(tx_context::epoch(ctx) >= storage.init_transfer_epoch + storage.epochs_delay, ETooEarly);

    storage.accepted = false;
    let new_admin = storage.pending_admin;
    storage.current_admin = new_admin;
    storage.pending_admin = @0x0;
    storage.init_transfer_epoch = SENTINEL_VALUE;

    transfer::transfer(cap, new_admin);

    emit(NewAdmin<T> { admin: new_admin });
  } 
}