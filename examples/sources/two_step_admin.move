/*
* An Example on how to implement a TimeLocked Two Step
*/
module examples::two_step_admin {
  
  use sui::transfer;
  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID};
  use sui::types::is_one_time_witness;
  use sui::tx_context::{Self, TxContext};

  // Errors
  const EZeroAddress: u64 = 0;
  const EInvalidAcceptSender: u64 = 1;
  const EAdminDidNotAccept: u64 = 2;
  const EInvalidWitness: u64 = 3;
  const ETooEarly: u64 = 4;

  // The owner of this object can add and remove minters + update the metadata
  // * Important NO store key, so it cannot be transferred
  struct AdminCap<phantom T: drop> has key {
    id: UID
  }

  // shared object
  struct TransferRequest<phantom T: drop> has key {
    id: UID,
    pending_admin: address,
    accepted: bool,
    delay: u64,
    start: u64,
  }

  /**
  * @dev It creates and returns an AdminCap and share its associated TransferRequest
  * @param witness type
  * @param c: delay before each transfer activation 
  * @returns AdminCap
  */
  public fun create<T: drop>(witness: T, delay: u64, ctx: &mut TxContext): AdminCap<T> {
    assert!(is_one_time_witness(&witness), EInvalidWitness);

    transfer::share_object(TransferRequest<T> {
        id: object::new(ctx),
        pending_admin: @0x0,
        accepted: false,
        delay,
        start: 0,
    });

    AdminCap<T> { id: object::new(ctx) }
  }

  /**
  * @dev It initiates the transfer process of the AdminCap
  * @param admin_cap: The AdminCap that will be transferred
  * @param request: The associated TransferRequest
  * @param recipient: the new admin address
  */
  public entry fun start_transfer<T: drop>(_: &AdminCap<T>, request: &mut TransferRequest<T>, recipient: address) {
    assert!(recipient != @0x0, EZeroAddress);
    request.pending_admin = recipient;
  } 

  /**
  * @dev It cancels the transfer of the Admin Cap
  * @param admin_cap: The AdminCap that will be transferred
  * @param request: The associated TransferRequest
  */
  public entry fun cancel_transfer<T: drop>(_: &AdminCap<T>, request: &mut TransferRequest<T>) {
    request.pending_admin = @0x0;
    request.accepted = false;
    request.start = 0;
  } 

  /**
  * @dev It allows the pending admin to accept the {AdminCap}
  * @param admin_cap: The AdminCap that will be transferred
  * @param request: The associated TransferRequest
  */
  public entry fun accept_transfer<T: drop>(c: &Clock, request: &mut TransferRequest<T>, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == request.pending_admin, EInvalidAcceptSender);

    request.accepted = true;
    request.start = clock::timestamp_ms(c);
  } 

  /**
  * @dev It transfers the AdminCap to the pending admin
  * @param admin_cap: The AdminCap that will be transferred
  * @param c: the clock object
  * @param request: The associated TransferRequest
  * @recipient the new admin address
  */
  public entry fun transfer<T: drop>(cap: AdminCap<T>, c: &Clock, request: &mut TransferRequest<T>) {
    // New admin must have accepted the request
    assert!(request.accepted, EAdminDidNotAccept);
    let now = clock::timestamp_ms(c);
    assert!(now >= request.start + request.delay, ETooEarly);

    transfer::transfer(cap, request.pending_admin);

    // reset Request data
    request.accepted = false;
    request.pending_admin = @0x0;
    request.start = 0;
  } 

  // Careful, this cannot be reverted
  public entry fun destroy_cap<T: drop>(cap: AdminCap<T>) {
    let AdminCap { id } = cap;
    object::delete(id);
  }

  // Not implemented yet because share object can't be deleted at the moment
  // see https://github.com/MystenLabs/sui/issues/12653
  // public entry fun destroy_request<T: drop>(request: TransferRequest<T>) {}
}