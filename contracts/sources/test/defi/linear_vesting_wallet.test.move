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
  }
}