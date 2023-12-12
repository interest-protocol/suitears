#[test_only]
module suitears::linear_vesting_wallet_tests {

  use sui::coin;
  use sui::clock;
  use sui::sui::SUI;
  use sui::tx_context;
  use sui::test_utils::assert_eq;

  use suitears::linear_vesting_wallet;

  #[test]
  fun test_end_to_end() {
    let ctx = tx_context::dummy();

    let start = 1;
    let end = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let c = clock::create_for_testing(&mut ctx);

    let wallet = linear_vesting_wallet::new(total_coin, &c, start, end, &mut ctx);

    assert_eq(linear_vesting_wallet::balance(&wallet), coin_amount);
    assert_eq(linear_vesting_wallet::start(&wallet), start);
    assert_eq(linear_vesting_wallet::released(&wallet), 0);
    assert_eq(linear_vesting_wallet::duration(&wallet), end);

    // Clock is at 2
    clock::increment_for_testing(&mut c, 2);

    let first_claim = 1 * coin_amount / 8;
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet::claim(&mut wallet, &c, &mut ctx)),
      first_claim
    );

    // Clock is at 7
    clock::increment_for_testing(&mut c, 5);

    let second_claim = (6 * coin_amount / 8) - first_claim;
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet::claim(&mut wallet, &c, &mut ctx)),
      second_claim
    );

    // Clock is at 9
    clock::increment_for_testing(&mut c, 2);

    let claim = coin_amount - second_claim - first_claim;
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet::claim(&mut wallet, &c, &mut ctx)),
      claim
    );

    linear_vesting_wallet::destroy_zero(wallet);
    clock::destroy_for_testing(c);
  }

  #[test]
  #[expected_failure(abort_code = linear_vesting_wallet::EInvalidStart)] 
  fun test_invalid_start_time() {
    let ctx = tx_context::dummy();

    let start = 2;
    let end = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let c = clock::create_for_testing(&mut ctx);
    clock::increment_for_testing(&mut c, 3);

    let wallet = linear_vesting_wallet::new(total_coin, &c, start, end, &mut ctx);

    linear_vesting_wallet::destroy_zero(wallet);
    clock::destroy_for_testing(c);
  }

  #[test]
  #[expected_failure] 
  fun test_destroy_non_zero_wallet() {
    let ctx = tx_context::dummy();

    let start = 2;
    let end = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let c = clock::create_for_testing(&mut ctx);

    let wallet = linear_vesting_wallet::new(total_coin, &c, start, end, &mut ctx);

    linear_vesting_wallet::destroy_zero(wallet);
    clock::destroy_for_testing(c);
  }
}