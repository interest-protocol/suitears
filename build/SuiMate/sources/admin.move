module suimate::admin {
    use sui::transfer;
  use sui::event::emit;
  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};

  const TIME_DELAY: u64 = 7;
  const SENTINEL_VALUE: u64 = 18446744073709551615;

  // Errors
  const EZeroAddress: u64 = 0;
  const EInvalidAcceptSender: u64 = 1;
  const EAdminDidNotAccept: u64 = 2;
  const ETooEarly: u64 = 4;

  // The owner of this object can add and remove minters + update the metadata
  struct AdminCap has key {
    id: UID
  }

  struct AdminStorage has key {
    id: UID,
    pending_admin: address,
    current_admin: address,
    accepted: bool,
    init_epoch: u64
  }

  // * Events

  struct StartTransferAdmin has copy, drop {
    current_admin: address,
    pending_admin: address
  }

  struct AcceptTransferAdmin has copy, drop {
    current_admin: address,
    pending_admin: address
  }

  struct CancelTransferAdmin has copy,drop {
    current_admin: address,
  }

  struct NewAdmin has copy, drop {
    admin: address
  }

  fun init(ctx: &mut TxContext) {

    let sender = tx_context::sender(ctx);
    
    // Send the AdminCap to the deployer
    transfer::transfer(
      AdminCap {
        id: object::new(ctx)
      },
      sender
    );

    transfer::share_object(
      AdminStorage {
        id: object::new(ctx),
        pending_admin: @0x0,
        current_admin: sender,
        accepted: false,
        init_epoch: SENTINEL_VALUE
      }
    );
  }

  /**
  * @dev It initiates the transfer process of the AdminCap
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  entry public fun start_transfer_admin(_: &AdminCap, storage: &mut AdminStorage, recipient: address, ctx: &mut TxContext) {
    assert!(recipient != @0x0, EZeroAddress);
    storage.pending_admin = recipient;
    storage.accepted = false;
    storage.init_epoch = tx_context::epoch(ctx);

    emit(StartTransferAdmin {
      current_admin: storage.current_admin,
      pending_admin: recipient
    });
  } 

  /**
  * @dev It cancels the transfer of the Admin Cap
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  entry public fun cancel_transfer_admin(_: &AdminCap, storage: &mut AdminStorage) {
    storage.pending_admin = @0x0;
    storage.accepted = false;
    storage.init_epoch = SENTINEL_VALUE;

    emit(CancelTransferAdmin {
      current_admin: storage.current_admin
    });
  } 

  /**
  * @dev It allows the pending admin to accept the {AdminCap}
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  entry public fun accept_transfer_admin(storage: &mut AdminStorage, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == storage.pending_admin, EInvalidAcceptSender);
    storage.accepted = true;

    emit(AcceptTransferAdmin {
      current_admin: storage.current_admin,
      pending_admin: storage.pending_admin
    });
  } 

  /**
  * @dev It transfers the {AdminCap} to the pending admin
  * @param admin_cap The AdminCap that will be transferred
  * @recipient the new admin address
  */
  entry public fun transfer_admin(cap: AdminCap, storage: &mut AdminStorage, ctx: &mut TxContext) {
    // New admin must accept the capability
    assert!(storage.accepted, EAdminDidNotAccept);
    assert!(tx_context::epoch(ctx) >= storage.init_epoch + TIME_DELAY, ETooEarly);

    storage.accepted = false;
    let new_admin = storage.pending_admin;
    storage.current_admin = new_admin;
    storage.pending_admin = @0x0;
    storage.init_epoch = SENTINEL_VALUE;

    transfer::transfer(cap, new_admin);

    emit(NewAdmin { admin: new_admin });
  } 
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }
}