#[test_only]
module suitears::farm_tests {

  use sui::clock;
  use sui::sui::SUI;
  use sui::transfer;
  use sui::coin::{CoinMetadata};
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, burn_for_testing, mint_for_testing};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use suitears::eth::{Self, ETH};
  use suitears::farm::{Self, Farm, Account};
  use suitears::test_utils::{people, scenario};

  const START_TIME: u64 = 10;
  const REWARDS_PER_SECOND: u64 = 10_000_000_000;
  const SUI_DECIMAL_SCALAR: u64 = 1_000_000_000;

  #[test]
  fun test_stake() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let farm = test::take_shared<Farm<ETH, SUI>>(test);
      let account = test::take_from_sender<Account<ETH, SUI>>(test);
      
      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(500, ctx(test)),
        &c,
        ctx(test)
      );

      assert_eq(burn_for_testing(reward_coin), 0);
      assert_eq(farm::amount(&account), 500);
      assert_eq(farm::reward_debt(&account), 0);
      assert_eq(farm::balance_stake_coin(&farm), 500);

      test::return_to_sender(test, account);
      test::return_shared(farm);
    };

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<ETH, SUI>>(test);
      let account = test::take_from_sender<Account<ETH, SUI>>(test);

      // 5 seconds of rewards
      clock::increment_for_testing(&mut c, 5000 + 10_000);

      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(500, ctx(test)),
        &c,
        ctx(test)
      );

      let accrued_rewards_per_share = farm::accrued_rewards_per_share(&farm);

      assert_eq(burn_for_testing(reward_coin), 5 * REWARDS_PER_SECOND);
      assert_eq(farm::amount(&account), 1000);
      assert_eq(farm::reward_debt(&account), (accrued_rewards_per_share * 1000) / (SUI_DECIMAL_SCALAR as u256));
      assert_eq(farm::balance_stake_coin(&farm), 1000);
      assert_eq(farm::last_reward_timestamp(&farm), 15_000 / 1000);

      test::return_to_sender(test, account);
      test::return_shared(farm);            
    };

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<ETH, SUI>>(test);
      let account = test::take_from_sender<Account<ETH, SUI>>(test);

      // 15 more seconds of rewards
      clock::increment_for_testing(&mut c, 15_000);

      let rewards_debt = farm::reward_debt(&account);
      let pending_rewards = farm::pending_rewards(&farm, &account, &c);    

      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        coin::zero(ctx(test)),
        &c,
        ctx(test)
      );

      let accrued_rewards_per_share = farm::accrued_rewards_per_share(&farm);

      assert_eq((burn_for_testing(reward_coin) as u256), ((1000 * accrued_rewards_per_share) / (SUI_DECIMAL_SCALAR as u256)) - rewards_debt);
      assert_eq((pending_rewards as u256), ((1000 * accrued_rewards_per_share) / (SUI_DECIMAL_SCALAR as u256)) - rewards_debt);
      assert_eq(farm::amount(&account), 1000);
      assert_eq(farm::reward_debt(&account), (accrued_rewards_per_share * 1000) / (SUI_DECIMAL_SCALAR as u256));
      assert_eq(farm::balance_stake_coin(&farm), 1000);
      assert_eq(farm::last_reward_timestamp(&farm), (15_000 * 2) / 1000);

      test::return_to_sender(test, account);
      test::return_shared(farm);          
    };

    clock::destroy_for_testing(c);
    test::end(scenario);
  }

  #[test]
  fun test_unstake() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let farm = test::take_shared<Farm<ETH, SUI>>(test);
      let account = test::take_from_sender<Account<ETH, SUI>>(test);
      
      burn_for_testing(farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(500, ctx(test)),
        &c,
        ctx(test)
      ));

      test::return_to_sender(test, account);
      test::return_shared(farm);      
    }; 

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<ETH, SUI>>(test);
      let account = test::take_from_sender<Account<ETH, SUI>>(test);

      // 5 seconds of rewards
      clock::increment_for_testing(&mut c, 5000 + 10_000);

      let pending_rewards = farm::pending_rewards(&farm, &account, &c);   

      let (stake_coin, reward_coin) = farm::unstake(
        &mut farm,
        &mut account,
        300,
        &c,
        ctx(test)
      );

      let accrued_rewards_per_share = farm::accrued_rewards_per_share(&farm);

      assert_eq(burn_for_testing(stake_coin), 300);
      assert_eq(burn_for_testing(reward_coin), REWARDS_PER_SECOND * 5);
      assert_eq(pending_rewards, REWARDS_PER_SECOND * 5);             
      assert_eq(farm::amount(&account), 200);
      assert_eq(farm::reward_debt(&account), (accrued_rewards_per_share * 200) / (SUI_DECIMAL_SCALAR as u256));
      assert_eq(farm::balance_stake_coin(&farm), 200);
      assert_eq(farm::last_reward_timestamp(&farm), 15_000 / 1000);
      assert_eq(accrued_rewards_per_share, (SUI_DECIMAL_SCALAR as u256) * ((REWARDS_PER_SECOND as u256) * 5) / 500);

      test::return_to_sender(test, account);
      test::return_shared(farm);           
    };

    clock::destroy_for_testing(c);
    test::end(scenario);       
  }

  fun set_up(test: &mut Scenario) {
    let (alice, bob) = people();

    next_tx(test, alice);
    {
      eth::init_for_testing(ctx(test));
    }; 

    next_tx(test, alice);
    {
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let c = clock::create_for_testing(ctx(test));

      let cap = farm::new_cap(ctx(test));
      let farm = farm::new_farm<ETH, SUI>(
        &mut cap,
        &eth_metadata,
        &c,
        REWARDS_PER_SECOND,
        START_TIME,
        ctx(test)
      );

      farm::add_rewards(&mut farm, mint_for_testing(10_000_000_000 * 1_000, ctx(test)));
      
      // send accounts to people
      transfer::public_transfer(farm::new_account(&farm, ctx(test)), alice);
      transfer::public_transfer(farm::new_account(&farm, ctx(test)), bob);

      transfer::public_share_object(farm);
      transfer::public_transfer(cap, alice);
      clock::destroy_for_testing(c);
      test::return_shared(eth_metadata);
    }; 
  }
}