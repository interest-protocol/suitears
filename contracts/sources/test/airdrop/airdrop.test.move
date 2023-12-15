#[test_only]
module suitears::airdrop_tests {

  use sui::clock;
  use sui::transfer;
  use sui::sui::SUI;
  use sui::test_utils::assert_eq;
  use sui::coin::{burn_for_testing, mint_for_testing};
  use sui::test_scenario::{Self as test, next_tx, ctx};
  
  use suitears::airdrop::{Self, Airdrop};
  use suitears::test_utils::scenario;

  #[test]
  fun test_get_airdrop() {
    let scenario = scenario();
    let alice = @0x94fbcf49867fd909e6b2ecf2802c4b2bba7c9b2d50a13abbb75dbae0216db82a;
    let bob = @0xb4536519beaef9d9207af2b5f83ae35d4ac76cc288ab9004b39254b354149d27;

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let airdrop = airdrop::new(
        mint_for_testing<SUI>(1000, ctx(test)),
        x"59d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace",
        1,
        &c, 
        ctx(test)
      );

      clock::increment_for_testing(&mut c, 1);

      let reward = airdrop::get_airdrop(
        &mut airdrop, 
        vector[x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624"],
        &c,
        55,
        ctx(test)
      );
      
      assert_eq(burn_for_testing(reward), 55);
      assert_eq(airdrop::has_account_claimed(
        &mut airdrop,
        vector[x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624"],
        55,
        alice
      ), true);
      transfer::public_share_object(airdrop);
    };

    next_tx(test, bob); 
    {
      let airdrop = test::take_shared<Airdrop<SUI>>(test);

      let reward = airdrop::get_airdrop(
        &mut airdrop, 
        vector[x"45db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5"],
        &c,
        27,
        ctx(test)
      );
      
      assert_eq(burn_for_testing(reward), 27);
      assert_eq(airdrop::has_account_claimed(
        &mut airdrop,
        vector[x"45db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5"],
        27,
        bob
      ), true);

      test::return_shared(airdrop);
    };    

    clock::destroy_for_testing(c);
    test::end(scenario); 
  }
}