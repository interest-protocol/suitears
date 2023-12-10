#[test_only]
module suitears::ac_collection_tests {

  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, next_tx, ctx};
  
  use suitears::owner;
  use suitears::test_utils::{people, scenario};
  use suitears::ac_collection::{new, new_cap, new_with_cap, borrow, borrow_mut, borrow_mut_uid, destroy, drop};  

  struct Key has copy, store, drop {}

  struct Collection has key, store {
    id: UID,
  }

  struct DropCollection has drop, store {
    value: u64
  }

  #[test]
  fun test_new() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    next_tx(test, alice);
    {
      let collection = DropCollection { value: 1 };
      let (cap, ac_collection) = new(collection, ctx(test));
      let ac_collection_id = object::id(&ac_collection);

      assert_eq(owner::contains(&cap, ac_collection_id), true);

      // Does not throw - real cap
      borrow_mut(&mut ac_collection, &cap);

      drop(ac_collection, &cap);
      owner::destroy(cap);
    };
    test::end(scenario);
  }

  #[test]
  fun test_new_with_cap() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    next_tx(test, alice);
    {

      let collection = DropCollection { value: 1 };
      let cap = new_cap(ctx(test));

      let ac_collection = new_with_cap(collection, &mut cap, ctx(test));
      let ac_collection_id = object::id(&ac_collection);

      assert_eq(owner::contains(&cap, ac_collection_id), true);

      // Does not throw - real cap
      borrow_mut(&mut ac_collection, &cap);

      drop(ac_collection, &cap);
      owner::destroy(cap);
    };
    test::end(scenario);
  }  

  #[test]
  fun test_destroy() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    next_tx(test, alice);
    {

      let collection = Collection { id: object::new(ctx(test)) };
      let cap = new_cap(ctx(test));
      
      let ac_collection = new_with_cap(collection, &mut cap, ctx(test));
      let ac_collection_id = object::id(&ac_collection);

      assert_eq(owner::contains(&cap, ac_collection_id), true);

      // Does not throw - real cap
      borrow_mut(&mut ac_collection, &cap);

      destroy_collection(destroy(ac_collection, &cap));
      owner::destroy(cap);
    };
    test::end(scenario);
  }

  #[test]
  fun test_access() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    next_tx(test, alice);
    {
      let collection = DropCollection { value: 1 };
      let (cap, ac_collection) = new(collection, ctx(test));

      let immut_value = drop_collection_borrow_value(borrow(&ac_collection));
      assert_eq(immut_value, 1);

      let mut_value = drop_collection_borrow_mut_value(borrow_mut(&mut ac_collection, &cap));
      *mut_value = 2;

      let immut_value = drop_collection_borrow_value(borrow(&ac_collection));
      assert_eq(immut_value, 2);

      let id = borrow_mut_uid(&mut ac_collection, &cap);
      df::add(id, Key {}, DropCollection { value: 2 });

      drop(ac_collection, &cap);      
      owner::destroy(cap);
    };
    test::end(scenario);     
  }

  #[test]
  #[expected_failure] 
  fun test_wrong_cap() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    next_tx(test, alice);
    {
      let collection = DropCollection { value: 1 };
      let (cap, ac_collection) = new(collection, ctx(test));

      let wrong_cap = new_cap(ctx(test));

      // throws - wrong cap
      borrow_mut(&mut ac_collection, &wrong_cap);

      drop(ac_collection, &cap);
      owner::destroy(cap);
      owner::destroy(wrong_cap);
    };
    test::end(scenario);    
  }

  fun drop_collection_borrow_value(collection: &DropCollection): u64 {
    collection.value
  }

  fun drop_collection_borrow_mut_value(collection: &mut DropCollection): &mut u64 {
    &mut collection.value
  }

  fun destroy_collection(collection: Collection) {
    let Collection { id } = collection;
    object::delete(id);
  }   
}