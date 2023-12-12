#[test_only]
module suitears::timelock_tests {

  use sui::clock;
  use sui::tx_context;
  use sui::test_utils::assert_eq;

  use suitears::timelock;

  struct Data has store, drop {
    value: u64
  }

  #[test]
  fun test_success_case() {
    let ctx = tx_context::dummy();
    let c = clock::create_for_testing(&mut ctx);
    let unlock_time = 1000;    

    let lock = timelock::lock(Data { value: 7 }, &c, unlock_time, &mut ctx);

    assert_eq(timelock::unlock_time(&lock), unlock_time);

    clock::set_for_testing(&mut c, unlock_time);

    let data = timelock::unlock(lock, &c);

    assert_eq(data.value, 7); 

    clock::destroy_for_testing(c);
  }

  #[test]
  #[expected_failure(abort_code = timelock::EInvalidTime)] 
  fun test_wrong_lock_time() {
    let ctx = tx_context::dummy();
    let c = clock::create_for_testing(&mut ctx);
    clock::set_for_testing(&mut c, 10);
    let unlock_time = 10;    

    let lock = timelock::lock(Data { value: 7 }, &c, unlock_time, &mut ctx);

    timelock::unlock(lock, &c);

    clock::destroy_for_testing(c);    
  }

  #[test]
  #[expected_failure(abort_code = timelock::ETooEarly)] 
  fun test_wrong_unlock_time() {
    let ctx = tx_context::dummy();
    let c = clock::create_for_testing(&mut ctx);
    let unlock_time = 10;    

    let lock = timelock::lock(Data { value: 7 }, &c, unlock_time, &mut ctx);
    
    clock::set_for_testing(&mut c, unlock_time - 1);
    timelock::unlock(lock, &c);

    clock::destroy_for_testing(c);    
  }  
}