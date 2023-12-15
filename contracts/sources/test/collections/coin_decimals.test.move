#[test_only]
module suitears::coin_decimals_tests {
  
  use sui::transfer;
  use sui::coin::CoinMetadata;
  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use suitears::coin_decimals;
  use suitears::s_btc::{Self, S_BTC};
  use suitears::s_eth::{Self, S_ETH};
  use suitears::test_utils::{people, scenario};
  
  #[test]
  fun test_case_one() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    init_state(test);

    next_tx(test, alice);
    { 
      let btc_metadata = test::take_shared<CoinMetadata<S_BTC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<S_ETH>>(test);

      let obj = coin_decimals::new(ctx(test));

      assert_eq(coin_decimals::contains<S_BTC>(&obj), false);
      assert_eq(coin_decimals::contains<S_ETH>(&obj), false);

      coin_decimals::add(&mut obj, &btc_metadata);
      coin_decimals::add(&mut obj, &eth_metadata);

      assert_eq(coin_decimals::decimals<S_BTC>(&obj), 6);
      assert_eq(coin_decimals::scalar<S_BTC>(&obj), 1_000_000);


      assert_eq(coin_decimals::decimals<S_ETH>(&obj), 9);
      assert_eq(coin_decimals::scalar<S_ETH>(&obj), 1_000_000_000);

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
      s_btc::init_for_testing(ctx(test));
      s_eth::init_for_testing(ctx(test));
    };   
  }
}