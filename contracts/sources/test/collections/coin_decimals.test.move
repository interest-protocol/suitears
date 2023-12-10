#[test_only]
module suitears::coin_decimals_tests {
  
  use sui::transfer;
  use sui::coin::CoinMetadata;
  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use suitears::coin_decimals;
  use suitears::btc::{Self, BTC};
  use suitears::eth::{Self, ETH};
  use suitears::test_utils::{people, scenario};
  
  #[test]
  fun test_case_one() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    init_state(test);

    next_tx(test, alice);
    { 
      let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);

      let obj = coin_decimals::new(ctx(test));

      assert_eq(coin_decimals::contains<BTC>(&obj), false);
      assert_eq(coin_decimals::contains<ETH>(&obj), false);

      coin_decimals::add(&mut obj, &btc_metadata);
      coin_decimals::add(&mut obj, &eth_metadata);

      assert_eq(coin_decimals::decimals<BTC>(&obj), 6);
      assert_eq(coin_decimals::scalar<BTC>(&obj), 1_000_000);


      assert_eq(coin_decimals::decimals<ETH>(&obj), 9);
      assert_eq(coin_decimals::scalar<ETH>(&obj), 1_000_000_000);

      // Does not throw
      coin_decimals::add(&mut obj, &eth_metadata);
      
      transfer::public_transfer(obj, alice);
      test::return_shared(btc_metadata);
      test::return_shared(eth_metadata);
    };
    test::end(scenario); 
  } 

  fun init_state(test: &mut Scenario) {
    let (alice, _) = people();
    next_tx(test, alice);
    {
      btc::init_for_testing(ctx(test));
      eth::init_for_testing(ctx(test));
    };   
  }
}