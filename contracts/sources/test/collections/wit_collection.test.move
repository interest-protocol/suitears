#[test_only]
module suitears::wit_collection_tests {

  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::test_utils::assert_eq;  
  use sui::test_scenario::{Self as test, next_tx, ctx};

 use suitears::test_utils::{people, scenario};
 use suitears::wit_collection::{new, borrow, borrow_mut, borrow_mut_uid, destroy, drop};  

  struct Witness has drop {}

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

      let wit_collection = new(collection, Witness {}, ctx(test));

      // Does not throw - real cap
      borrow_mut(&mut wit_collection, Witness {});

      drop(wit_collection, Witness {});
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
      
      let wit_collection = new(collection, Witness {}, ctx(test));

      // Does not throw - real cap
      borrow_mut(&mut wit_collection, Witness {});

      destroy_collection(destroy(wit_collection, Witness {}));
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
      let wit_collection = new(collection, Witness {}, ctx(test));

      let immut_value = drop_collection_borrow_value(borrow(&wit_collection));
      assert_eq(immut_value, 1);

      let mut_value = drop_collection_borrow_mut_value(borrow_mut(&mut wit_collection, Witness {}));
      *mut_value = 2;

      let immut_value = drop_collection_borrow_value(borrow(&wit_collection));
      assert_eq(immut_value, 2);

      let id = borrow_mut_uid(&mut wit_collection, Witness {});
      df::add(id, Key {}, DropCollection { value: 2 });

      drop(wit_collection, Witness {});      
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