#[test_only]
module suitears::permanent_lock_tests {

  use sui::clock;
  use sui::transfer;
  use sui::tx_context;
  use sui::test_utils::assert_eq;

  use examples::permanent_lock;

  struct Data has store, drop {
    value: u64
  }


  #[test]
  fun test_success_case() {
    let ctx = tx_context::dummy();
    let c = clock::create_for_testing(&mut ctx);
    clock::set_for_testing(&mut c, 10);
    let time_delay = 1000;
    let lock = permanent_lock::lock(Data { value: 7 }, &c, time_delay, &mut ctx);

    assert_eq(permanent_lock::start(&lock), 10);
    assert_eq(permanent_lock::time_delay(&lock), time_delay);
    assert_eq(permanent_lock::unlock_time(&lock), time_delay + 10);

    clock::increment_for_testing(&mut c, time_delay + 1);

    let (data, potato) = permanent_lock::unlock_temporarily(lock, &c);

    assert_eq(data.value, 7);

    let lock = permanent_lock::relock(data, &c, potato, &mut ctx);

    // Transfer to dead
    transfer::public_transfer(lock, @0x0);
    clock::destroy_for_testing(c);
  }
}