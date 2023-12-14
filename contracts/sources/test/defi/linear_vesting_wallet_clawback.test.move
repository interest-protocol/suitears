#[test_only]
module suitears::linear_vesting_wallet_clawback_tests {

  use sui::coin;
  use sui::clock;
  use sui::sui::SUI;
  use sui::tx_context;
  use sui::test_utils::assert_eq;

  use suitears::owner;
  use suitears::linear_vesting_wallet_clawback;

  #[test]
  fun test_end_to_end_with_no_clawback() {
    let ctx = tx_context::dummy();

    let start = 1;
    let end = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let c = clock::create_for_testing(&mut ctx);

    let (owner_cap, recipient_cap, wallet) = linear_vesting_wallet_clawback::new(total_coin, &c, start, end, &mut ctx);

    assert_eq(linear_vesting_wallet_clawback::balance(&wallet), coin_amount);
    assert_eq(linear_vesting_wallet_clawback::start(&wallet), start);
    assert_eq(linear_vesting_wallet_clawback::released(&wallet), 0);
    assert_eq(linear_vesting_wallet_clawback::duration(&wallet), end);

    // Clock is at 2
    clock::increment_for_testing(&mut c, 2);

    let first_claim = 1 * coin_amount / 8;
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet_clawback::claim(&mut wallet, &recipient_cap, &c, &mut ctx)),
      first_claim
    );

    // Clock is at 7
    clock::increment_for_testing(&mut c, 5);

    let second_claim = (6 * coin_amount / 8) - first_claim;
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet_clawback::claim(&mut wallet, &recipient_cap, &c, &mut ctx)),
      second_claim
    );

    // Clock is at 9
    clock::increment_for_testing(&mut c, 2);

    let claim = coin_amount - second_claim - first_claim;
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet_clawback::claim(&mut wallet, &recipient_cap, &c, &mut ctx)),
      claim
    );

    linear_vesting_wallet_clawback::destroy_zero(wallet);
    clock::destroy_for_testing(c);
    owner::destroy(owner_cap);
    owner::destroy(recipient_cap);
  }

  #[test]
  fun test_end_to_end_with_clawback() {
    let ctx = tx_context::dummy();

    let start = 1;
    let end = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let c = clock::create_for_testing(&mut ctx);

    let (owner_cap, recipient_cap, wallet) = linear_vesting_wallet_clawback::new(total_coin, &c, start, end, &mut ctx);

    assert_eq(linear_vesting_wallet_clawback::balance(&wallet), coin_amount);
    assert_eq(linear_vesting_wallet_clawback::start(&wallet), start);
    assert_eq(linear_vesting_wallet_clawback::released(&wallet), 0);
    assert_eq(linear_vesting_wallet_clawback::duration(&wallet), end);

    // Clock is at 2
    clock::increment_for_testing(&mut c, 2);

    let first_claim = coin_amount / 8;
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet_clawback::claim(&mut wallet, &recipient_cap, &c, &mut ctx)),
      first_claim
    );

    // Clock is at 6
    clock::increment_for_testing(&mut c, 4);

    let second_claim = ((5 * coin_amount) / 8) - first_claim;
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet_clawback::claim(&mut wallet, &recipient_cap, &c, &mut ctx)),
      second_claim
    );

     // Clock is at 7
    clock::increment_for_testing(&mut c, 1);

    let third_claim = coin_amount - ((6 * coin_amount) / 8);
    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet_clawback::clawback(&mut wallet, owner_cap, &c, &mut ctx)),
      third_claim
    );

    // Clock is at 9
    clock::increment_for_testing(&mut c, 2);

    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet_clawback::claim(&mut wallet, &recipient_cap, &c, &mut ctx)),
      ((6 * coin_amount) / 8) - second_claim - first_claim
    );

    assert_eq(
      linear_vesting_wallet_clawback::balance(&wallet),
      0
    );

    clock::increment_for_testing(&mut c, 10);

    assert_eq(
      coin::burn_for_testing(linear_vesting_wallet_clawback::claim(&mut wallet, &recipient_cap, &c, &mut ctx)),
      0
    );

    linear_vesting_wallet_clawback::destroy_zero(wallet);
    clock::destroy_for_testing(c);
    owner::destroy(recipient_cap);
  }  

  #[test]
  #[expected_failure(abort_code = linear_vesting_wallet_clawback::EInvalidStart)] 
  fun test_invalid_start_time() {
    let ctx = tx_context::dummy();

    let start = 2;
    let end = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let c = clock::create_for_testing(&mut ctx);
    clock::increment_for_testing(&mut c, 3);

    let (owner_cap, recipient_cap, wallet) = linear_vesting_wallet_clawback::new(total_coin, &c, start, end, &mut ctx);

    linear_vesting_wallet_clawback::destroy_zero(wallet);
    clock::destroy_for_testing(c);
    owner::destroy(owner_cap);
    owner::destroy(recipient_cap);
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

    let (owner_cap, recipient_cap, wallet) = linear_vesting_wallet_clawback::new(total_coin, &c, start, end, &mut ctx);

    linear_vesting_wallet_clawback::destroy_zero(wallet);
    clock::destroy_for_testing(c);
    owner::destroy(owner_cap);
    owner::destroy(recipient_cap);
  }
}