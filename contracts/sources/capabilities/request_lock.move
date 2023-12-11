/*
* RequestPotato is a hot potato
* RequestPotato can only be destroyed if all requests have been completed
* To complete a Request the function quest::complete_request must be called with the Witness
* It is possible to make a RequestPotato with no Requests!
* A Request might contain a payload
*/
module suitears::request_lock {
  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::tx_context::TxContext;
  use sui::vec_set::{Self, VecSet};

  const EWrongRequest: u64 = 0;
  const ERequestHasPayload: u64 = 1;
  const ERequestHasNoPayload: u64 = 2;
  const ERequestHasAlreadyBeenAdded: u64 = 3;

  struct Lock<phantom Issuer: drop> {
    required_requests: vector<Request>,
    completed_requests: VecSet<TypeName>
  }

  struct Request has key, store {
    id: UID,
    name: TypeName,
    has_payload: bool
  }

  struct RequestKey has copy, drop, store { witness: TypeName }

  public fun name(req: &Request): TypeName {
    req.name
  }

  public fun has_payload(req: &Request): bool {
    req.has_payload
  }

  public fun borrow_required_requests<Witness: drop>(lock: &Lock<Witness>): &vector<Request> {
    &lock.required_requests
  }

  public fun completed_requests<Witness: drop>(potato: &Lock<Witness>): vector<TypeName> {
    *vec_set::keys(&potato.completed_requests)
  }  

  public fun new_lock<Witness: drop>(_: Witness): Lock<Witness> {
    Lock { required_requests: vector[], completed_requests: vec_set::empty()}
  }

  public fun new_request<RequestName: drop>(ctx: &mut TxContext): Request {
    Request {
      id: object::new(ctx),
      name: type_name::get<RequestName>(),
      has_payload: false
    }
  }

  public fun new_request_with_payload<RequestName: drop, Payload: store>(payload: Payload, ctx: &mut TxContext): Request {
    let name = type_name::get<RequestName>();
    let req = Request {
      id: object::new(ctx),
      name: type_name::get<RequestName>(),
      has_payload: true
    };

    df::add(&mut req.id, RequestKey { witness: name }, payload);

    req
  }

  public fun add<Witness: drop>(lock: &mut Lock<Witness>, req: Request) {
    let length = vector::length(&lock.required_requests);
    let index = 0;

    while (length > index) {
      assert!(vector::borrow(&lock.required_requests, index).name != req.name, ERequestHasAlreadyBeenAdded);
      index = index + 1;
    };

    vector::push_back(&mut lock.required_requests, req);
  }

  public fun complete<Witness: drop, Request: drop>(lock: &mut Lock<Witness>, _: Request) {
    let num_of_requests = vector::length(&lock.required_requests);
    let req = vector::borrow(&lock.required_requests, num_of_requests);
    let completed_req_name = type_name::get<Request>();

    assert!(req.name == completed_req_name, EWrongRequest);
    assert!(!req.has_payload, ERequestHasPayload);
    vec_set::insert(&mut lock.completed_requests, completed_req_name);
  }

  public fun complete_with_payload<Witness: drop, Request: drop, Payload: store>(lock: &mut Lock<Witness>, _: Request): Payload {
    let num_of_requests = vector::length(&lock.required_requests);
    let req = vector::borrow_mut(&mut lock.required_requests, num_of_requests);
    let completed_req_name = type_name::get<Request>();

    assert!(req.name == completed_req_name, EWrongRequest);

    let key = RequestKey { witness: completed_req_name };

    assert!(req.has_payload, ERequestHasNoPayload);

    vec_set::insert(&mut lock.completed_requests, completed_req_name);
    df::remove(&mut req.id, key)
  }

  public fun destroy<Witness: drop>(lock: Lock<Witness>) {
    let Lock { required_requests, completed_requests } = lock;

    let num_of_requests = vector::length(&required_requests);
    let completed_requests = vec_set::into_keys(completed_requests);

    let index = 0;

    while (num_of_requests > index) {
      let Request { id, name, has_payload: _ } = vector::remove(&mut required_requests, 0);

      assert!(name == vector::remove(&mut completed_requests, 0), EWrongRequest);

      object::delete(id);

      index = index + 1;
    };

    vector::destroy_empty(required_requests);
    vector::destroy_empty(completed_requests);
  }

  // @dev It allows the frontend to read the content of a Payload with devInspectTransactionBlock
  #[allow(unused_function)]
  fun borrow_payload<Payload: store>(req: &Request): &Payload {
    assert!(req.has_payload, ERequestHasNoPayload);

    df::borrow<RequestKey, Payload>(&req.id, RequestKey { witness: req.name })
  }
}