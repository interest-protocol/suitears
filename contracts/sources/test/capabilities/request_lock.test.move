#[test_only]
module suitears::request_lock_tests {
  use std::vector;
  use std::type_name;

  use sui::tx_context;
  use sui::test_utils::assert_eq;

  use suitears::request_one;
  use suitears::request_two;
  use suitears::request_lock;
  use suitears::request_issuer_test;

  struct Data has store, drop {
    value: u64
  }

  #[test]
  fun test_success_case() {
    let ctx = tx_context::dummy();
    let lock = request_issuer_test::create_lock();
    
    request_lock::add(&mut lock, request_lock::new_request<request_one::Witness>(&mut ctx));
    request_lock::add(&mut lock, request_lock::new_request_with_payload<request_two::Witness, Data>(Data { value: 7 }, &mut ctx));

    assert_eq(request_lock::completed_requests(&lock), vector[]);

    let required_requests = request_lock::borrow_required_requests(&lock);

    let req1 = vector::borrow(required_requests, 0);
    assert_eq(request_lock::name(req1), type_name::get<request_one::Witness>());
    assert_eq(request_lock::has_payload(req1), false);

    let req2 = vector::borrow(required_requests, 1);
    assert_eq(request_lock::name(req2), type_name::get<request_two::Witness>());
    assert_eq(request_lock::has_payload(req2), true);

    request_one::complete(&mut lock);
    assert_eq(request_lock::completed_requests(&lock), vector[type_name::get<request_one::Witness>()]);

    let payload = request_two::complete<Data>(&mut lock);
    assert_eq(request_lock::completed_requests(&lock), vector[type_name::get<request_one::Witness>(), type_name::get<request_two::Witness>()]);

    assert_eq(payload.value, 7);

    request_lock::destroy(lock);
  }

  #[test]
  #[expected_failure(abort_code = request_lock::EWrongRequest)]
  fun test_wrong_complete_request() {
    let ctx = tx_context::dummy();
    let lock = request_issuer_test::create_lock();
    
    request_lock::add(&mut lock, request_lock::new_request<request_one::Witness>(&mut ctx));
    request_lock::add(&mut lock, request_lock::new_request_with_payload<request_two::Witness, Data>(Data { value: 7 }, &mut ctx));

    request_two::complete<Data>(&mut lock);

    request_lock::destroy(lock);
  }

  #[test]
  #[expected_failure(abort_code = request_lock::ERequestHasPayload)]
  fun test_wrong_complete_with_payload() {
    let ctx = tx_context::dummy();
    let lock = request_issuer_test::create_lock();
    
    request_lock::add(&mut lock, request_lock::new_request<request_one::Witness>(&mut ctx));
    request_lock::add(&mut lock, request_lock::new_request_with_payload<request_two::Witness, Data>(Data { value: 7 }, &mut ctx));

    request_one::complete(&mut lock);
    request_two::wrong_complete(&mut lock);

    request_lock::destroy(lock);
  }

  #[test]
  #[expected_failure(abort_code = request_lock::ERequestHasPayload)]
  fun test_wrong_complete_with_no_payload() {
    let ctx = tx_context::dummy();
    let lock = request_issuer_test::create_lock();
    
    request_lock::add(&mut lock, request_lock::new_request<request_one::Witness>(&mut ctx));
    request_lock::add(&mut lock, request_lock::new_request_with_payload<request_two::Witness, Data>(Data { value: 7 }, &mut ctx));

    request_one::complete(&mut lock);
    request_two::wrong_complete(&mut lock);

    request_lock::destroy(lock);
  }

  #[test]  
  #[expected_failure]
  fun test_invalid_destroy() {
    let ctx = tx_context::dummy();
    let lock = request_issuer_test::create_lock();
    
    request_lock::add(&mut lock, request_lock::new_request<request_one::Witness>(&mut ctx));
    request_lock::add(&mut lock, request_lock::new_request_with_payload<request_two::Witness, Data>(Data { value: 7 }, &mut ctx));

    request_one::complete(&mut lock);

    request_lock::destroy(lock);    
  }
}

#[test_only]
module suitears::request_issuer_test {

  use suitears::request_lock::{Self, Lock};

  struct Issuer has drop {}

  public fun create_lock(): Lock<Issuer> {
    request_lock::new_lock(Issuer {})
  }
}

#[test_only]
module suitears::request_one {
  
  use suitears::request_lock::{Self, Lock};
  use suitears::request_issuer_test::Issuer;

  struct Witness has drop {}

  public fun complete(self: &mut Lock<Issuer>) {
    request_lock::complete(self, Witness{});
  }
}

#[test_only]
module suitears::request_two {
  
  use suitears::request_lock::{Self, Lock};
  use suitears::request_issuer_test::Issuer;

  struct Witness has drop {}

  public fun complete<Payload: store>(self: &mut Lock<Issuer>): Payload {
    request_lock::complete_with_payload(self, Witness{})
  }

  public fun wrong_complete(self: &mut Lock<Issuer>) {
    request_lock::complete(self, Witness{});
  }
}