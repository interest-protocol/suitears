/*
* RequestPotato is a hot potato
* RequestPotato can only be destroyed if all requests have been completed
* To complete a Request the function quest::complete_request must be called with the Witness
* It is possible to make a RequestPotato with no Requests!
* A Request might contain a payload
*/
module suitears::request {
  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::tx_context::TxContext;
  use sui::object::{Self, UID, ID};
  use sui::vec_set::{Self, VecSet};
  use sui::dynamic_object_field as dfo;

  const EWrongRequest: u64 = 0;
  const ERequestHasPayload: u64 = 1;
  const ERequestHasNoPayload: u64 = 2;
  const ERequestHasAlreadyBeenAdded: u64 = 3;

  struct RequestKey has copy, drop, store { witness: TypeName }

  struct Request has key, store {
    id: UID,
    name: TypeName,
    has_payload: bool
  }

  struct RequestPotato<phantom Issuer: drop> {
    required_requests: vector<Request>,
    completed_requests: VecSet<TypeName>
  }

  public fun request_name(req: &Request): TypeName {
    req.name
  }

  public fun request_has_payload(req: &Request): bool {
    req.has_payload
  }

  public fun new_potato<Witness: drop>(_: Witness): RequestPotato<Witness> {
    RequestPotato { required_requests: vector[], completed_requests: vec_set::empty()}
  }

  public fun new_request<RequestName: drop>(ctx: &mut TxContext): Request {
    Request {
      id: object::new(ctx),
      name: type_name::get<RequestName>(),
      has_payload: false
    }
  }

  public fun new_request_with_payload<RequestName: drop, Payload: store + key>(payload: Payload, ctx: &mut TxContext): Request {
    let name = type_name::get<RequestName>();
    let req = Request {
      id: object::new(ctx),
      name: type_name::get<RequestName>(),
      has_payload: true
    };

    dfo::add(&mut req.id, RequestKey { witness: name }, payload);

    req
  }

  public fun add_request<Witness: drop>(potato: &mut RequestPotato<Witness>, req: Request) {
    let length = vector::length(&potato.required_requests);
    let index = 0;

    while (length > index) {
      assert!(vector::borrow(&potato.required_requests, index).name != req.name, ERequestHasAlreadyBeenAdded);
      index = index + 1;
    };

    vector::push_back(&mut potato.required_requests, req);
  }

  public fun potato_required_requests<Witness: drop>(potato: &RequestPotato<Witness>): vector<TypeName> {
    let names = vector[];
    let length = vector::length(&potato.required_requests);
    let index = 0;

    while (length > index) {

      vector::push_back(&mut names, vector::borrow(&potato.required_requests, index).name);

      index = index + 1;
    };

    names
  }

  public fun potato_completed_requests<Witness: drop>(potato: &RequestPotato<Witness>): vector<TypeName> {
    *vec_set::keys(&potato.completed_requests)
  }

  public fun complete_request<Witness: drop, Request: drop>(_: Request, potato: &mut RequestPotato<Witness>) {
    let num_of_requests = vector::length(&potato.required_requests);
    let req = vector::borrow(&potato.required_requests, num_of_requests);
    let completed_req_name = type_name::get<Request>();

    assert!(req.name == completed_req_name, EWrongRequest);
    assert!(!req.has_payload, ERequestHasPayload);
    vec_set::insert(&mut potato.completed_requests, completed_req_name);
  }

  public fun complete_request_with_payload<Witness: drop, Request: drop, Payload: store + key>(_: Request, potato: &mut RequestPotato<Witness>): Payload {
    let num_of_requests = vector::length(&potato.required_requests);
    let req = vector::borrow_mut(&mut potato.required_requests, num_of_requests);
    let completed_req_name = type_name::get<Request>();

    assert!(req.name == completed_req_name, EWrongRequest);

    let key = RequestKey { witness: completed_req_name };

    assert!(req.has_payload, ERequestHasNoPayload);

    vec_set::insert(&mut potato.completed_requests, completed_req_name);
    dfo::remove(&mut req.id, key)
  }

  public fun destroy_potato<Witness: drop>(potato: RequestPotato<Witness>) {
    let RequestPotato { required_requests, completed_requests } = potato;

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
  fun request_payload_id<Payload: store + key>(req: &Request): ID {
    assert!(req.has_payload, ERequestHasNoPayload);

    let payload = dfo::borrow<RequestKey, Payload>(&req.id, RequestKey { witness: req.name });
    object::id(payload)
  }
}