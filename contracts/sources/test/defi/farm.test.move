#[test_only]
module suitears::farm_tests {

  use sui::clock;
  use sui::sui::SUI;
  use sui::transfer;
  use sui::coin::{CoinMetadata};
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, burn_for_testing, mint_for_testing};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use suitears::s_eth::{Self, S_ETH};
  use suitears::owner::{Self, OwnerCap};
  use suitears::test_utils::{people, scenario};
  use suitears::farm::{Self, Farm, FarmWitness, Account};

  const START_TIME: u64 = 10;
  const REWARDS_PER_SECOND: u64 = 10_000_000_000;
  const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;

  #[test]
  fun test_stake() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
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
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);

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
      assert_eq(farm::reward_debt(&account), (accrued_rewards_per_share * 1000) / (ETH_DECIMAL_SCALAR as u256));
      assert_eq(farm::balance_stake_coin(&farm), 1000);
      assert_eq(farm::last_reward_timestamp(&farm), 15_000 / 1000);

      test::return_to_sender(test, account);
      test::return_shared(farm);            
    };

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);

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

      assert_eq((burn_for_testing(reward_coin) as u256), ((1000 * accrued_rewards_per_share) / (ETH_DECIMAL_SCALAR as u256)) - rewards_debt);
      assert_eq((pending_rewards as u256), ((1000 * accrued_rewards_per_share) / (ETH_DECIMAL_SCALAR as u256)) - rewards_debt);
      assert_eq(farm::amount(&account), 1000);
      assert_eq(farm::reward_debt(&account), (accrued_rewards_per_share * 1000) / (ETH_DECIMAL_SCALAR as u256));
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
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
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
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);

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
      assert_eq(farm::reward_debt(&account), (accrued_rewards_per_share * 200) / (ETH_DECIMAL_SCALAR as u256));
      assert_eq(farm::balance_stake_coin(&farm), 200);
      assert_eq(farm::last_reward_timestamp(&farm), 15_000 / 1000);
      assert_eq(accrued_rewards_per_share, (ETH_DECIMAL_SCALAR as u256) * ((REWARDS_PER_SECOND as u256) * 5) / 500);

      test::return_to_sender(test, account);
      test::return_shared(farm);           
    };

    clock::destroy_for_testing(c);
    test::end(scenario);       
  }

  #[test]
  fun test_end_to_end() {
    let scenario = scenario();
    let (alice, bob) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));
    clock::increment_for_testing(&mut c, 10_000);

    next_tx(test, alice);      
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
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

    next_tx(test, bob);      
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);

      // Bob missed 5 seconds of rewards
      clock::increment_for_testing(&mut c, 5_000);
      
      burn_for_testing(farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(300, ctx(test)),
        &c,
        ctx(test)
      ));

      test::return_to_sender(test, account);
      test::return_shared(farm);         
    };

    let accrued_rewards_per_share = (REWARDS_PER_SECOND as u256) * 4 * (ETH_DECIMAL_SCALAR as u256) / 800  + (REWARDS_PER_SECOND as u256) * 5 * (ETH_DECIMAL_SCALAR as u256) / 500;

    next_tx(test, alice);  
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test); 

      // 9 seconds
      clock::increment_for_testing(&mut c, 4_000);


      assert_eq(farm::amount(&account), 500);
      assert_eq(farm::reward_debt(&account), 0);
      assert_eq(farm::balance_stake_coin(&farm), 800);
      assert_eq(farm::last_reward_timestamp(&farm), 15_000 / 1000);
      assert_eq(farm::accrued_rewards_per_share(&farm), (REWARDS_PER_SECOND as u256) * 5 * (ETH_DECIMAL_SCALAR as u256) / 500);

      let (stake_coin, reward_coin) = farm::unstake(
        &mut farm,
        &mut account,
        300,
        &c,
        ctx(test)
      );

      assert_eq(burn_for_testing(stake_coin), 300);
      assert_eq((burn_for_testing(reward_coin) as u256), accrued_rewards_per_share * 500 / (ETH_DECIMAL_SCALAR as u256));
      assert_eq(farm::accrued_rewards_per_share(&farm), accrued_rewards_per_share);
      assert_eq(farm::amount(&account), 200);
      assert_eq(farm::reward_debt(&account), 200 * accrued_rewards_per_share / (ETH_DECIMAL_SCALAR as u256));
      assert_eq(farm::balance_stake_coin(&farm), 500);
      assert_eq(farm::last_reward_timestamp(&farm), 19_000 / 1000);

      test::return_to_sender(test, account);
      test::return_shared(farm);        
    };

    next_tx(test, bob);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);

      assert_eq(farm::amount(&account), 300);
      assert_eq(farm::reward_debt(&account), (300 * (REWARDS_PER_SECOND as u256) * 5 * (ETH_DECIMAL_SCALAR as u256) / 500) / (ETH_DECIMAL_SCALAR as u256));

      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(100, ctx(test)),
        &c,
        ctx(test)
      );

      assert_eq((burn_for_testing(reward_coin) as u256), (300 * (REWARDS_PER_SECOND as u256) * 4 * (ETH_DECIMAL_SCALAR as u256) / 800) / (ETH_DECIMAL_SCALAR as u256));

      assert_eq(farm::amount(&account), 400);
      assert_eq(farm::reward_debt(&account), 400 * accrued_rewards_per_share / (ETH_DECIMAL_SCALAR as u256));
      assert_eq(farm::balance_stake_coin(&farm), 600);
      assert_eq(farm::last_reward_timestamp(&farm), 19_000 / 1000);

      test::return_to_sender(test, account);
      test::return_shared(farm);    
    };

    clock::destroy_for_testing(c);
    test::end(scenario);  
  }
  
    
  #[test]
  #[lint_allow(share_owned)]
  fun test_no_rewards() {
    let scenario = scenario();
    let (alice, bob) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);
    {
      s_eth::init_for_testing(ctx(test));
    };   

    next_tx(test, alice);
    {
      let eth_metadata = test::take_shared<CoinMetadata<S_ETH>>(test);

      let cap = farm::new_cap(ctx(test));
      let farm = farm::new_farm<S_ETH, SUI>(
        &mut cap,
        &eth_metadata,
        &c,
        REWARDS_PER_SECOND,
        1,
        ctx(test)
      );

      // Only have 5 seconds of rewards
      farm::add_rewards(&mut farm, &c, mint_for_testing(10_000_000_000 * 5, ctx(test)));
      
      // send accounts to people
      transfer::public_transfer(farm::new_account(&farm, ctx(test)), alice);
      transfer::public_transfer(farm::new_account(&farm, ctx(test)), bob);

      transfer::public_share_object(farm);
      transfer::public_transfer(cap, alice);
      test::return_shared(eth_metadata);      
    };

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
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

     // Pass 6 seconds to get all rewards
    clock::increment_for_testing(&mut c, 6001);

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        coin::zero(ctx(test)),
        &c,
        ctx(test)
      );

      assert_eq(burn_for_testing(reward_coin), 10_000_000_000 * 5);
      assert_eq(farm::balance_reward_coin(&farm), 0);

      test::return_to_sender(test, account);
      test::return_shared(farm);      
    };

    next_tx(test, bob);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
      burn_for_testing(farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(250, ctx(test)),
        &c,
        ctx(test)
      ));

      test::return_to_sender(test, account);
      test::return_shared(farm); 
    };

    // Pass 6 seconds to get all rewards
    clock::increment_for_testing(&mut c, 6001);  

    next_tx(test, bob);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
      let (stake_coin, reward_coin) = farm::unstake(
        &mut farm,
        &mut account,
        100,
        &c,
        ctx(test)
      );

      let accrued_rewards_per_share = farm::accrued_rewards_per_share(&farm);

      assert_eq(burn_for_testing(stake_coin), 100);
      assert_eq(burn_for_testing(reward_coin), 0);
      assert_eq(farm::amount(&account), 150);
      assert_eq(farm::reward_debt(&account), (accrued_rewards_per_share * 150) / (ETH_DECIMAL_SCALAR as u256));

      farm::add_rewards(&mut farm, &c, mint_for_testing(10_000_000_000 * 5, ctx(test)));     

      test::return_to_sender(test, account);
      test::return_shared(farm); 
    };      

    // Pass 6 seconds to get all rewards
    clock::increment_for_testing(&mut c, 6001);  

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        coin::zero(ctx(test)),
        &c,
        ctx(test)
      );

      assert_eq(burn_for_testing(reward_coin), 10_000_000_000 * 5 * 500 / 650);
      // bob rewards
      assert_eq(farm::balance_reward_coin(&farm), (10_000_000_000 * 5 * 150 / 650) + 1);

      test::return_to_sender(test, account);
      test::return_shared(farm);      
    };

    // Pass 6 seconds to get all rewards
    clock::increment_for_testing(&mut c, 6001);  

    next_tx(test, bob);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        coin::zero(ctx(test)),
        &c,
        ctx(test)
      );

      assert_eq(burn_for_testing(reward_coin), (10_000_000_000 * 5 * 150 / 650) + 1);
      // bob rewards
      assert_eq(farm::balance_reward_coin(&farm), 0);

      test::return_to_sender(test, account);
      test::return_shared(farm);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);      
  }

  #[test]
  fun test_update_rewards_per_second() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));
    clock::increment_for_testing(&mut c, 10_000);

    next_tx(test, alice);      
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let cap = test::take_from_sender<OwnerCap<FarmWitness>>(test);

      assert_eq(farm::rewards_per_second(&farm), REWARDS_PER_SECOND);

      farm::update_rewards_per_second(
        &mut farm,
        &cap,
        1,
        &c
      );

      test::return_to_sender(test, cap);
      test::return_shared(farm);         
    }; 
    clock::destroy_for_testing(c);
    test::end(scenario);     
  }

  #[test]
  #[expected_failure(abort_code = owner::ENotAllowed)] 
  fun test_wrong_admin_update_rewards() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));
    clock::increment_for_testing(&mut c, 10_000);

    next_tx(test, alice); 
    {
      let wrong_cap = farm::new_cap(ctx(test)); 
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);

      farm::update_rewards_per_second(
        &mut farm,
        &wrong_cap,
        1,
        &c
      );

      owner::destroy(wrong_cap);
      test::return_shared(farm);      
    };
    clock::destroy_for_testing(c);
    test::end(scenario);        
  }

  #[test]
  #[expected_failure(abort_code = owner::ENotAllowed)] 
  fun test_wrong_admin_borrow_uid() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));
    clock::increment_for_testing(&mut c, 10_000);

    next_tx(test, alice); 
    {
      let wrong_cap = farm::new_cap(ctx(test)); 
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);

      farm::borrow_mut_uid(&mut farm, &wrong_cap);

      owner::destroy(wrong_cap);
      test::return_shared(farm);      
    };
    clock::destroy_for_testing(c);
    test::end(scenario);        
  }

  #[test]
  #[expected_failure(abort_code = owner::ENotAllowed)] 
  fun test_wrong_admin_destroy_farm() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let wrong_cap = farm::new_cap(ctx(test)); 
      let eth_metadata = test::take_shared<CoinMetadata<S_ETH>>(test);

      let cap = farm::new_cap(ctx(test));
      let farm = farm::new_farm<S_ETH, SUI>(
        &mut cap,
        &eth_metadata,
        &c,
        REWARDS_PER_SECOND,
        1,
        ctx(test)
      );

      farm::destroy_zero_farm(farm, &wrong_cap);
  
      transfer::public_transfer(cap, alice);
      test::return_shared(eth_metadata);
      owner::destroy(wrong_cap);     
    };
    clock::destroy_for_testing(c);
    test::end(scenario);        
  }  

  #[test]
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = farm::EInvalidStartTime)] 
  fun test_invalid_start_time() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);
    {
      s_eth::init_for_testing(ctx(test));
    };   

    next_tx(test, alice);
    {
      let eth_metadata = test::take_shared<CoinMetadata<S_ETH>>(test);

      let cap = farm::new_cap(ctx(test));
      let farm = farm::new_farm<S_ETH, SUI>(
        &mut cap,
        &eth_metadata,
        &c,
        REWARDS_PER_SECOND,
        0,
        ctx(test)
      );
  
      // send accounts to people
      transfer::public_transfer(farm::new_account(&farm, ctx(test)), alice);

      transfer::public_share_object(farm);
      transfer::public_transfer(cap, alice);
      test::return_shared(eth_metadata);      
    }; 
    
    clock::destroy_for_testing(c);
    test::end(scenario);      
  }

  #[test]
  #[expected_failure(abort_code = farm::EAccountHasValue)]   
  fun test_destroy_non_zero_account() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(500, ctx(test)),
        &c,
        ctx(test)
      );

      burn_for_testing(reward_coin);
      farm::destroy_zero_account(account);

      test::return_shared(farm);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);           
  }

  #[test]
  #[expected_failure(abort_code = farm::EInsufficientStakeAmount)]   
  fun test_invalid_unstake_amount() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
      let reward_coin = farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(500, ctx(test)),
        &c,
        ctx(test)
      );

      burn_for_testing(reward_coin);
      test::return_to_sender(test, account);
      test::return_shared(farm);
    };

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);

      let (stake_coin, reward_coin) = farm::unstake(
        &mut farm,
        &mut account,
        501,
        &c,
        ctx(test)
      );

      burn_for_testing(stake_coin);
      burn_for_testing(reward_coin);

      test::return_to_sender(test, account);
      test::return_shared(farm);           
    };    

    clock::destroy_for_testing(c);
    test::end(scenario);           
  }  

  #[test]
  #[expected_failure(abort_code = farm::EInvalidAccount)]   
  fun test_stake_invalid_account() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let cap = farm::new_cap(ctx(test));
      let eth_metadata = test::take_shared<CoinMetadata<S_ETH>>(test);

      let farm2 = farm::new_farm<S_ETH, SUI>(
        &mut cap,
        &eth_metadata,
        &c,
        REWARDS_PER_SECOND,
        START_TIME,
        ctx(test)
      );

      let wrong_account = farm::new_account(&farm2, ctx(test));
      
      let reward_coin = farm::stake(
        &mut farm,
        &mut wrong_account,
        mint_for_testing(500, ctx(test)),
        &c,
        ctx(test)
      );

      burn_for_testing(reward_coin);
      transfer::public_transfer(wrong_account, alice);
      transfer::public_transfer(cap, alice);
      test::return_shared(farm);
      test::return_shared(farm2);
      test::return_shared(eth_metadata);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);           
  } 

  #[test]
  #[expected_failure(abort_code = farm::EInvalidAccount)]   
  fun test_unstake_invalid_account() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up(test);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let account = test::take_from_sender<Account<S_ETH, SUI>>(test);
      
      burn_for_testing(farm::stake(
        &mut farm,
        &mut account,
        mint_for_testing(250, ctx(test)),
        &c,
        ctx(test)
      ));

      test::return_to_sender(test, account);
      test::return_shared(farm); 
    };

    next_tx(test, alice);  
    {
      let farm = test::take_shared<Farm<S_ETH, SUI>>(test);
      let cap = farm::new_cap(ctx(test));
      let eth_metadata = test::take_shared<CoinMetadata<S_ETH>>(test);

      let farm2 = farm::new_farm<S_ETH, SUI>(
        &mut cap,
        &eth_metadata,
        &c,
        REWARDS_PER_SECOND,
        START_TIME,
        ctx(test)
      );

      let wrong_account = farm::new_account(&farm2, ctx(test));
      
      let (stake_coin, reward_coin) = farm::unstake(
        &mut farm,
        &mut wrong_account,
        100,
        &c,
        ctx(test)
      );

      burn_for_testing(stake_coin);
      burn_for_testing(reward_coin);
      transfer::public_transfer(wrong_account, alice);
      transfer::public_transfer(cap, alice);
      test::return_shared(farm);
      test::return_shared(farm2);
      test::return_shared(eth_metadata);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);           
  }    
  
  #[lint_allow(share_owned)]
  fun set_up(test: &mut Scenario) {
    let (alice, bob) = people();

    next_tx(test, alice);
    {
      s_eth::init_for_testing(ctx(test));
    }; 

    next_tx(test, alice);
    {
      let eth_metadata = test::take_shared<CoinMetadata<S_ETH>>(test);
      let c = clock::create_for_testing(ctx(test));

      let cap = farm::new_cap(ctx(test));
      let farm = farm::new_farm<S_ETH, SUI>(
        &mut cap,
        &eth_metadata,
        &c,
        REWARDS_PER_SECOND,
        START_TIME,
        ctx(test)
      );

      farm::add_rewards(&mut farm, &c, mint_for_testing(10_000_000_000 * 1_000, ctx(test)));
      
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