#[test_only]
module suitears::dao_treasury_tests {

  use sui::clock;
  use sui::object;
  use sui::transfer;
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, mint_for_testing};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};


  use suitears::s_eth::S_ETH;
  use suitears::dao::{Self, Dao};
  use suitears::test_utils::{people, scenario};
  use suitears::dao_treasury::{Self, DaoTreasury};

  const DAO_VOTING_DELAY: u64 = 10;
  const DAO_VOTING_PERIOD: u64 = 20;  
  const DAO_QUORUM_RATE: u64 = 7_00_000_000;
  const DAO_MIN_ACTION_DELAY: u64 = 7;
  const DAO_MIN_QUORUM_VOTES: u64 = 1234;

  const FLASH_LOAN_FEE: u64 = 5000000; // 0.5%

  struct InterestDAO has drop {}

  #[test]
  fun test_treasury_view_functions() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    // Dao is initialized correctly
    next_tx(test, alice);  
    {
      let treasury = test::take_shared<DaoTreasury<InterestDAO>>(test);
      let dao = test::take_shared<Dao<InterestDAO>>(test);

      assert_eq(dao_treasury::balance<InterestDAO, S_ETH>(&treasury), 0);

      dao_treasury::donate<InterestDAO, S_ETH>(&mut treasury, mint_for_testing(1234, ctx(test)), ctx(test));

      assert_eq(dao_treasury::balance<InterestDAO, S_ETH>(&treasury), 1234);
      assert_eq(dao_treasury::dao<InterestDAO>(&treasury), object::id(&dao));

      test::return_shared(dao);
      test::return_shared(treasury);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);  
  }

  #[test]
  fun test_flash_loan() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    // Dao is initialized correctly
    next_tx(test, alice); 
    {
      let treasury = test::take_shared<DaoTreasury<InterestDAO>>(test);
      let dao = test::take_shared<Dao<InterestDAO>>(test);

      dao_treasury::donate<InterestDAO, S_ETH>(&mut treasury, mint_for_testing(1234, ctx(test)), ctx(test));

      let (borrowed_coin, receipt) = dao_treasury::flash_loan<InterestDAO, S_ETH>(
        &mut treasury,
        1234,
        ctx(test)
      );

      assert_eq(coin::value(&borrowed_coin), 1234);

      let fee = (1234 * FLASH_LOAN_FEE / 1_000_000_000) + 1;

      coin::join(&mut borrowed_coin, mint_for_testing(fee, ctx(test)));

      assert_eq(dao_treasury::fee(&receipt), fee);
      assert_eq(dao_treasury::amount(&receipt), 1234);

      dao_treasury::repay_flash_loan(
        &mut treasury,
        receipt,
        borrowed_coin
      );

      test::return_shared(dao);
      test::return_shared(treasury);            
    };
    clock::destroy_for_testing(c);
    test::end(scenario);         
  }  

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao_treasury::ERepayAmountTooLow)]
  fun test_low_flash_loan_repay() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    // Dao is initialized correctly
    next_tx(test, alice); 
    {
      let treasury = test::take_shared<DaoTreasury<InterestDAO>>(test);
      let dao = test::take_shared<Dao<InterestDAO>>(test);

      dao_treasury::donate<InterestDAO, S_ETH>(&mut treasury, mint_for_testing(1234, ctx(test)), ctx(test));

      let (borrowed_coin, receipt) = dao_treasury::flash_loan<InterestDAO, S_ETH>(
        &mut treasury,
        1234,
        ctx(test)
      );

      assert_eq(coin::value(&borrowed_coin), 1234);

      coin::join(&mut borrowed_coin, mint_for_testing((1234 * FLASH_LOAN_FEE / 1_000_000_000), ctx(test)));

      dao_treasury::repay_flash_loan(
        &mut treasury,
        receipt,
        borrowed_coin
      );

      test::return_shared(dao);
      test::return_shared(treasury);            
    };
    clock::destroy_for_testing(c);
    test::end(scenario);      
  }  

  #[lint_allow(share_owned)]
  fun set_up(test: &mut Scenario) {

    let (alice, _) = people();
    next_tx(test, alice);
    {
      let (dao, treasury) = dao::new_for_testing<InterestDAO, S_ETH>(
        DAO_VOTING_DELAY,
        DAO_VOTING_PERIOD,
        DAO_QUORUM_RATE,
        DAO_MIN_ACTION_DELAY,
        DAO_MIN_QUORUM_VOTES,
        ctx(test)
      );
      
      transfer::public_share_object(dao);
      transfer::public_share_object(treasury);
    };
  }  
}