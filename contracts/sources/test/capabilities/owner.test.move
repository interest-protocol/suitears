#[test_only]
module suitears::owner_tests {
  
  use sui::object;
  use sui::tx_context;
  use sui::test_utils::assert_eq;

  use suitears::owner;

  struct Witness has drop {}

  #[test]
  fun test_sucess_case() {
    let ctx = tx_context::dummy();
    let uid = object::new(&mut ctx);

    let cap = owner::new(Witness{}, vector[], &mut ctx);

    assert_eq(owner::contains(&cap, *object::uid_as_inner(&uid)), false);

    owner::add(&mut cap, Witness {}, *object::uid_as_inner(&uid));

    assert_eq(owner::contains(&cap, *object::uid_as_inner(&uid)), true);

    assert_eq(owner::of(&cap), vector[*object::uid_as_inner(&uid)]);

    let uid2 = object::new(&mut ctx);
    owner::add(&mut cap, Witness {}, *object::uid_as_inner(&uid2));
    // wont add twice
    owner::add(&mut cap, Witness {}, *object::uid_as_inner(&uid2));

    assert_eq(owner::of(&cap), vector[*object::uid_as_inner(&uid), object::uid_to_inner(&uid2)]);
    assert_eq(owner::contains(&cap, *object::uid_as_inner(&uid2)), true);

    owner::remove(&mut cap, Witness {}, *object::uid_as_inner(&uid2));
    // Wonmt throw
    owner::remove(&mut cap, Witness {}, *object::uid_as_inner(&uid2));

    assert_eq(owner::of(&cap), vector[*object::uid_as_inner(&uid)]);
    assert_eq(owner::contains(&cap, *object::uid_as_inner(&uid)), true);
    assert_eq(owner::contains(&cap, *object::uid_as_inner(&uid2)), false);

    // Wont throw cuz successful
    owner::assert_ownership(&cap, *object::uid_as_inner(&uid));

    owner::destroy(cap);
    object::delete(uid);
    object::delete(uid2);
  }

  #[test]
  #[expected_failure(abort_code = owner::ENotAllowed)] 
  fun test_failure_case() {
    let ctx = tx_context::dummy();
    let uid = object::new(&mut ctx);
    let uid2 = object::new(&mut ctx);
    let cap = owner::new(Witness{}, vector[], &mut ctx);

    owner::add(&mut cap, Witness {}, *object::uid_as_inner(&uid));
    owner::assert_ownership(&cap, *object::uid_as_inner(&uid2));

    owner::destroy(cap);
    object::delete(uid);
    object::delete(uid2);
  }
}