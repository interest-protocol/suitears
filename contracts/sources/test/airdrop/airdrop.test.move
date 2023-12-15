#[test_only]
module suitears::airdrop_tests {

  use sui::clock;
  use sui::transfer;
  use sui::sui::SUI;
  use sui::test_utils::assert_eq;
  use sui::coin::{burn_for_testing, mint_for_testing};
  use sui::test_scenario::{Self as test, next_tx, ctx};
  
  use suitears::airdrop;
  use suitears::test_utils::scenario;

  #[test]
  fun test_get_airdrop() {
    let scenario = scenario();
    let alice = @0x94fbcf49867fd909e6b2ecf2802c4b2bba7c9b2d50a13abbb75dbae0216db82a;

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let airdrop = airdrop::new(
        mint_for_testing<SUI>(1000, ctx(test)),
        x"19436cd6d5007ff352041265c9b5cab0a16247f6c318d43bf8c3f6e279ad4d69",
        1,
        &c, 
        ctx(test)
      );

      clock::increment_for_testing(&mut c, 1);

      let reward = airdrop::get_airdrop(
        &mut airdrop, 
        vector[x"55aebd4112cb029bc198a0d45c397902e0d1f190ae8afa6ef67760addb97b43b"],
        &c,
        55,
        ctx(test)
      );

      assert_eq(burn_for_testing(reward), 55);

      transfer::public_share_object(airdrop);
    };
    clock::destroy_for_testing(c);
    test::end(scenario); 
  }
}