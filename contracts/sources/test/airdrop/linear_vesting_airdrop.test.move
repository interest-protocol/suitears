#[test_only]
module suitears::linear_vesting_airdrop_tests {

  use sui::clock;
  use sui::transfer;
  use sui::sui::SUI;
  use sui::test_utils::assert_eq;
  use sui::coin::mint_for_testing;
  use sui::test_scenario::{Self as test, next_tx, ctx};
  
  use suitears::test_utils::scenario;
  use suitears::linear_vesting_wallet as wallet;
  use suitears::linear_vesting_airdrop::{Self as airdrop, Airdrop};

  const DURATION: u64 = 10;

  #[test]
  #[lint_allow(share_owned)]
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
        DURATION,
        &c, 
        ctx(test)
      );

      clock::increment_for_testing(&mut c, 1);

      let wallet = airdrop::get_airdrop(
        &mut airdrop, 
        vector[x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624"],
        &c,
        55,
        ctx(test)
      );
      
      assert_eq(wallet::balance(&wallet), 55);
      assert_eq(wallet::duration(&wallet), DURATION);
      assert_eq(airdrop::has_account_claimed(
        &airdrop,
        vector[x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624"],
        55,
        alice
      ), true);
      transfer::public_transfer(wallet, alice);
      transfer::public_share_object(airdrop);
    };

    next_tx(test, bob); 
    {
      let airdrop = test::take_shared<Airdrop<SUI>>(test);

      let wallet = airdrop::get_airdrop(
        &mut airdrop, 
        vector[x"45db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5"],
        &c,
        27,
        ctx(test)
      );
      
      assert_eq(wallet::balance(&wallet), 27);
      assert_eq(wallet::duration(&wallet), DURATION);
      assert_eq(airdrop::has_account_claimed(
        &airdrop,
        vector[x"45db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5"],
        27,
        bob
      ), true);

      transfer::public_transfer(wallet, bob);
      test::return_shared(airdrop);
    };    

    clock::destroy_for_testing(c);
    test::end(scenario); 
  }

  #[test]
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = airdrop::EInvalidRoot)]
  fun test_error_invalid_root() {
    let scenario = scenario();
    let alice = @0x94fbcf49867fd909e6b2ecf2802c4b2bba7c9b2d50a13abbb75dbae0216db82a;

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let airdrop = airdrop::new(
        mint_for_testing<SUI>(1000, ctx(test)),
        vector[],
        1,
        DURATION,
        &c, 
        ctx(test)
      );

      transfer::public_share_object(airdrop);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);  
  }     

  #[test]
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = airdrop::EInvalidStartTime)]
  fun test_error_invalid_create_time() {
    let scenario = scenario();
    let alice = @0x94fbcf49867fd909e6b2ecf2802c4b2bba7c9b2d50a13abbb75dbae0216db82a;

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));
    clock::increment_for_testing(&mut c, 2);

    next_tx(test, alice); 
    {
      let airdrop = airdrop::new(
        mint_for_testing<SUI>(1000, ctx(test)),
        x"59d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace",
        1,
        DURATION,
        &c, 
        ctx(test)
      );

      transfer::public_share_object(airdrop);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);  
  }    

  #[test]
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = airdrop::EAlreadyClaimed)]
  fun test_error_trying_to_claim_again() {
    let scenario = scenario();
    let alice = @0x94fbcf49867fd909e6b2ecf2802c4b2bba7c9b2d50a13abbb75dbae0216db82a;

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let airdrop = airdrop::new(
        mint_for_testing<SUI>(1000, ctx(test)),
        x"59d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace",
        1,
        DURATION,
        &c, 
        ctx(test)
      );

      clock::increment_for_testing(&mut c, 1);

      let wallet = airdrop::get_airdrop(
        &mut airdrop, 
        vector[x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624"],
        &c,
        55,
        ctx(test)
      );
      
       transfer::public_transfer(wallet, alice);

      let wallet = airdrop::get_airdrop(
        &mut airdrop, 
        vector[x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624"],
        &c,
        55,
        ctx(test)
      );
      
       transfer::public_transfer(wallet, alice);

      transfer::public_share_object(airdrop);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);     
  }

  #[test]
  #[lint_allow(share_owned)]
  #[expected_failure]
  fun test_error_wrong_amount() {
    let scenario = scenario();
    let alice = @0x94fbcf49867fd909e6b2ecf2802c4b2bba7c9b2d50a13abbb75dbae0216db82a;

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let airdrop = airdrop::new(
        mint_for_testing<SUI>(1000, ctx(test)),
        x"59d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace",
        1,
        DURATION,
        &c, 
        ctx(test)
      );

      clock::increment_for_testing(&mut c, 1);

      let wallet = airdrop::get_airdrop(
        &mut airdrop, 
        vector[x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624"],
        &c,
        55 + 1,
        ctx(test)
      );
      
       transfer::public_transfer(wallet, alice);

      transfer::public_share_object(airdrop);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);     
  }  
}