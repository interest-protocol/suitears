#[test_only]
module suitears::dao_tests {
  use std::type_name;

  use sui::object;
  use sui::transfer;
  use sui::clock::{Self, Clock};
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, burn_for_testing, mint_for_testing};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use suitears::dao::{Self, Dao};
  use suitears::s_eth::{Self, S_ETH};
  use suitears::dao_treasury::DaoTreasury;
  use suitears::test_utils::{people, scenario};

  const DAO_VOTING_DELAY: u64 = 10;
  const DAO_VOTING_PERIOD: u64 = 20;  
  const DAO_QUORUM_RATE: u64 = 7_00_000_000;
  const DAO_MIN_ACTION_DELAY: u64 = 7;
  const DAO_MIN_QUORUM_VOTES: u64 = 1234;

  struct InterestDAO has drop {}

  struct AuthorizedWitness has drop {}

  #[test]
  fun initiates_correctly() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    // Dao is initialized correctly
    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      let treasury = test::take_shared<DaoTreasury<InterestDAO>>(test);

      assert_eq(dao::voting_delay(&dao), DAO_VOTING_DELAY);
      assert_eq(dao::voting_period(&dao), DAO_VOTING_PERIOD);
      assert_eq(dao::dao_voting_quorum_rate(&dao), DAO_QUORUM_RATE);
      assert_eq(dao::min_action_delay(&dao), DAO_MIN_ACTION_DELAY);
      assert_eq(dao::min_quorum_votes(&dao), DAO_MIN_QUORUM_VOTES);
      assert_eq(dao::treasury(&dao), object::id(&treasury));
      assert_eq(dao::dao_coin_type(&dao), type_name::get<S_ETH>());

      test::return_shared(treasury);
      test::return_shared(dao);
    };
    clock::destroy_for_testing(c);
    test::end(scenario);
  }   

  #[test]
  fun test_end_to_end_not_executable_proposal() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    next_tx(test, alice);  
    {

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