/*
* @title Request Lock
*
* @notice A library to ensure that a set of requests are completed during a {TransactionBlock}. 
*
* @dev The {Lock} is a hot potato. It has to be destroyed in the same {TransactionBlock} that is created. 
* @dev The {Lock} can only be destroyed once all the requests are completed in order. 
* @dev To complete a Request the function {complete} must be called with a Witness. 
* @dev It is possible to create a {Lock} with no Requests!
* @dev A Request might contain a payload. 
*/
module suitears::request_lock {
  // === Imports ===

  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::tx_context::TxContext;
  use sui::vec_set::{Self, VecSet};

  // === Errors ===

  // @dev Throws if one provides the wrong Witness once when completing a request.  
  // @dev Requests must be completed in order. 
  const EWrongRequest: u64 = 0;
  // @dev Thrown if a request with a payload is completed with the function {complete} instead of {complete_with_payload}.
  const ERequestHasPayload: u64 = 1;
  // @dev Thrown if a request without a payload is completed with the function {complete_with_payload} instead of {complete}.  
  const ERequestHasNoPayload: u64 = 2;
  // @dev Thrown if one tries to add two requests with the same Witness. 
  const ERequestHasAlreadyBeenAdded: u64 = 3;

  // @dev It can only be destroyed if all `required_requests` have been completed. 
  struct Lock<phantom Issuer: drop> {
    // The requests that must be completed before calling the function {destroy}.  
    required_requests: vector<Request>,
    // The current completed requests. It starts empty.       
    completed_requests: VecSet<TypeName>
  }

  // @dev Represents a single request.  
  // @dev It may have a payload saved as a dynamic field. 
  struct Request has key, store {
    id: UID,
    // The name of the Witness associated with this request. 
    name: TypeName,
    // Indicates if this request has a payload saved as a dynamic Field. 
    has_payload: bool
  }

  // @dev The key used to access a Payload saved in a request
  struct RequestKey has copy, drop, store { witness: TypeName }

  // === Public View Function ===    

  /*
  * @notice Returns a request Witness `std::type_name::TypeName`. 
  *
  * @param req A {Request} 
  * @return TypeName. The Witness `std::type_name::TypeName` of `req`.  
  */
  public fun name(req: &Request): TypeName {
    req.name
  }

  /*
  * @notice Checks if a {Request} has a payload. 
  *
  * @param req A {Request} 
  * @return bool. True if it has a payload.  
  */
  public fun has_payload(req: &Request): bool {
    req.has_payload
  }

  /*
  * @notice Returns an immutable reference to the `req.required_requests`. 
  *
  * @dev It is not possible to read a {Request} payload on-chain before completing it. 
  *
  * @param lock A {Lock<Issuer>} 
  * @return &vector<Request>. Vector of all Requests.  
  */
  public fun borrow_required_requests<Witness: drop>(lock: &Lock<Witness>): &vector<Request> {
    &lock.required_requests
  }

  /*
  * @notice Returns a copy of all completed requests. 
  *
  * @param lock A {Lock<Issuer>} 
  * @return vector<TypeName>. A vector of all completed requests witness names.  
  */
  public fun completed_requests<Witness: drop>(potato: &Lock<Witness>): vector<TypeName> {
    *vec_set::keys(&potato.completed_requests)
  }  

  // === Public Create Function ===    

  /*
  * @notice Creates a {Lock<Witness>}. 
  *
  * @param _ A witness to tie the lock to a module. 
  * @return Lock<Witness>. A hot potato that can only be destroyed if all required requests are completed.  
  */
  public fun new_lock<Witness: drop>(_: Witness): Lock<Witness> {
    Lock { required_requests: vector[], completed_requests: vec_set::empty()}
  }

  /*
  * @notice Creates a {Request}. 
  *
  * @return Request. It has no payload.
  */
  public fun new_request<RequestName: drop>(ctx: &mut TxContext): Request {
    Request {
      id: object::new(ctx),
      name: type_name::get<RequestName>(),
      has_payload: false
    }
  }

  /*
  * @notice Creates a {Request} `req` with a payload saved as a dynamic field under the key {RequestKey}. 
  *
  * @return Request. It has no payload.
  */
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

  // === Public Mutative Function ===   

  /*
  * @notice Adds a {Request} to the `lock`. 
  *
  * @dev To destroy a {Lock<Witness>}. Requests must be completed in order. 
  *
  * @param lock A {Lock<Issuer>}.  
  * @param req A {Request}.  
  *
  * aborts-if 
  * - The `req.name` has already been added to the `lock.required_requests`
  */
  public fun add<Witness: drop>(lock: &mut Lock<Witness>, req: Request) {
    let length = vector::length(&lock.required_requests);
    let index = 0;

    while (length > index) {
      assert!(vector::borrow(&lock.required_requests, index).name != req.name, ERequestHasAlreadyBeenAdded);
      index = index + 1;
    };

    vector::push_back(&mut lock.required_requests, req);
  }

  /*
  * @notice Completes a task by adding the `Witness` name to the `lock.required_requests`. 
  *
  * @dev To destroy a {Lock<Witness>}. Tasks must be completed in order. 
  *
  * @param lock A {Lock<Issuer>}.  
  * @param _ A {Request} witness.  
  *
  * aborts-if 
  * - The `req.name` has already been added to the `lock.required_requests`
  * - if the {Request} has a payload. 
  */
  public fun complete<Witness: drop, Request: drop>(lock: &mut Lock<Witness>, _: Request) {
    let num_of_requests = vector::length(&lock.required_requests);
    let req = vector::borrow(&lock.required_requests, num_of_requests);
    let completed_req_name = type_name::get<Request>();

    assert!(req.name == completed_req_name, EWrongRequest);
    assert!(!req.has_payload, ERequestHasPayload);
    vec_set::insert(&mut lock.completed_requests, completed_req_name);
  }

  /*
  * @notice Completes a task by adding the `Witness` name to the `lock.required_requests` and returns the payload. 
  *
  * @dev To destroy a {Lock<Witness>}. Tasks must be completed in order. 
  *
  * @param lock A {Lock<Issuer>}.  
  * @param _ A {Request} witness.  
  *
  * aborts-if 
  * - The `req.name` has already been added to the `lock.required_requests`
  * - if the {Request} does not have a payload. 
  */
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

  /*
  * @notice Destroys the `lock`. 
  *
  * @param lock A {Lock<Issuer>}.   
  *
  * aborts-if 
  * - a request has not been completed.
  * - a request was completed in the wrong order.  
  */
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

  // === Private Utility Function ===    

 /*
  * @notice Returns an immutable reference to a paylaod. 
  *
  * @dev Allows the frontend to read the Payload. 
  *
  * @param req A {Request}.  
  * @return &Payload. 
  *
  * aborts-if 
  * - `req` does not have a payload.  
  */
  #[allow(unused_function)]
  fun borrow_payload<Payload: store>(req: &Request): &Payload {
    assert!(req.has_payload, ERequestHasNoPayload);

    df::borrow<RequestKey, Payload>(&req.id, RequestKey { witness: req.name })
  }
}