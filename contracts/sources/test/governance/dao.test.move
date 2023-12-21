#[test_only]
module suitears::dao_tests {
  use std::option;
  use std::type_name;
  use std::string;

  use sui::object;
  use sui::transfer;
  use sui::sui::SUI;
  use sui::clock::{Self, Clock};
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, burn_for_testing, mint_for_testing};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};


  use suitears::s_eth::S_ETH;
  use suitears::dao_treasury::DaoTreasury;
  use suitears::test_utils::{people, scenario};
  use suitears::dao::{Self, Dao, Proposal, Vote};

  /// Proposal state
  const PENDING: u8 = 1;
  const ACTIVE: u8 = 2;
  const DEFEATED: u8 = 3;
  const AGREED: u8 = 4;
  const QUEUED: u8 = 5;
  const FINISHED: u8 = 7;

  const DAO_VOTING_DELAY: u64 = 10;
  const DAO_VOTING_PERIOD: u64 = 20;  
  const DAO_QUORUM_RATE: u64 = 7_00_000_000;
  const DAO_MIN_ACTION_DELAY: u64 = 7;
  const DAO_MIN_QUORUM_VOTES: u64 = 1234;

  const PROPOSAL_ACTION_DELAY: u64 = 11;
  const PROPOSAL_QUORUM_VOTES: u64 = 2341;

  struct InterestDAO has drop {}

  struct AuthorizedWitness has drop {}

  #[test]
  #[lint_allow(share_owned)]
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

    // Test proposal
    next_tx(test, alice);
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      
      clock::increment_for_testing(&mut c, 123);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::some(type_name::get<AuthorizedWitness>()),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      assert_eq(dao::proposer(&proposal), alice);
      assert_eq(dao::start_time(&proposal), 123 + DAO_VOTING_DELAY);
      assert_eq(dao::end_time(&proposal), 123 + DAO_VOTING_DELAY + DAO_VOTING_PERIOD);
      assert_eq(dao::for_votes(&proposal), 0);
      assert_eq(dao::against_votes(&proposal), 0);
      assert_eq(dao::eta(&proposal), 0);
      assert_eq(dao::quorum_votes(&proposal), PROPOSAL_QUORUM_VOTES);
      assert_eq(dao::voting_quorum_rate(&proposal), DAO_QUORUM_RATE);
      assert_eq(dao::hash(&proposal), string::utf8(b"hash"));
      assert_eq(*option::borrow(&dao::authorized_witness(&proposal)), type_name::get<AuthorizedWitness>());
      assert_eq(dao::capability_id(&proposal), option::none());
      assert_eq(dao::coin_type(&proposal), type_name::get<S_ETH>());

      transfer::public_share_object(proposal);
      test::return_shared(dao);
    };

    // test votes
    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);
      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(123, ctx(test)),
        true,
        ctx(test)
      );

      assert_eq(dao::balance(&vote), 123);
      assert_eq(dao::proposal_id(&vote), object::id(&proposal));
      assert_eq(dao::vote_end_time(&vote), 123 + DAO_VOTING_DELAY + DAO_VOTING_PERIOD);
      assert_eq(dao::agree(&vote), true);
      assert_eq(dao::state(&proposal, &c), ACTIVE);

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);
    };

    clock::destroy_for_testing(c);
    test::end(scenario);
  }   

  #[test]
  #[lint_allow(share_owned)]
  fun test_end_to_end_sucessful_not_executable_proposal() {
    let scenario = scenario();
    let (alice, bob) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      
      clock::increment_for_testing(&mut c, 123);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      assert_eq(dao::state(&proposal, &c), PENDING);

      transfer::public_share_object(proposal);
      test::return_shared(dao);      
    };

    // 30 NO votes
    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(900, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, bob);

      test::return_shared(proposal);      
    };

    // 70 YES votes
    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        true,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);      
    };

    // Queue the proposal
    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_PERIOD);

      assert_eq(dao::state(&proposal, &c), AGREED);

      dao::queue(&mut proposal, &c);

      assert_eq(dao::state(&proposal, &c), QUEUED);

      clock::increment_for_testing(&mut c, PROPOSAL_ACTION_DELAY);

      assert_eq(dao::state(&proposal, &c), FINISHED);
      assert_eq(dao::for_votes(&proposal), 2100);
      assert_eq(dao::against_votes(&proposal), 900);

      test::return_shared(proposal);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);
  }

  #[test]
  #[lint_allow(share_owned)]
  fun test_end_to_end_defeated_proposal() {
  let scenario = scenario();
    let (alice, bob) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      
      clock::increment_for_testing(&mut c, 123);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      assert_eq(dao::state(&proposal, &c), PENDING);

      transfer::public_share_object(proposal);
      test::return_shared(dao);      
    };

    // 30 NO votes
    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(900, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, bob);

      test::return_shared(proposal);      
    };

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2000, ctx(test)),
        true,
        ctx(test)
      );

      transfer::public_transfer(vote, bob);

      test::return_shared(proposal);      
    };    

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_PERIOD);

      assert_eq(dao::state(&proposal, &c), DEFEATED);

      clock::increment_for_testing(&mut c, PROPOSAL_ACTION_DELAY);

      assert_eq(dao::state(&proposal, &c), DEFEATED);
      assert_eq(dao::for_votes(&proposal), 2000);
      assert_eq(dao::against_votes(&proposal), 900);

      test::return_shared(proposal);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }  

  #[test]
  #[lint_allow(share_owned)]
  fun test_vote_mechanisms() {
    let scenario = scenario();
    let (_, bob) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up_with_proposal(test, &c);

    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(900, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, bob);

      test::return_shared(proposal);      
    };

    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);
      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);

      assert_eq(dao::for_votes(&proposal), 0);
      assert_eq(dao::against_votes(&proposal), 900);

      dao::change_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &mut vote,
        &c,
        ctx(test)
      );

      assert_eq(dao::for_votes(&proposal), 900);
      assert_eq(dao::against_votes(&proposal), 0);

      test::return_to_sender(test, vote);
      test::return_shared(proposal);        
    }; 
    
    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);
      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);

      let revoked_coin = dao::revoke_vote<InterestDAO, S_ETH>(
        &mut proposal,
        vote,
        &c,
        ctx(test)
      );

      assert_eq(burn_for_testing(revoked_coin), 900);
      assert_eq(dao::for_votes(&proposal), 0);
      assert_eq(dao::against_votes(&proposal), 0);

      test::return_shared(proposal);        
    };   

    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(1234567, ctx(test)),
        true,
        ctx(test)
      );

      assert_eq(dao::for_votes(&proposal), 1234567);
      assert_eq(dao::against_votes(&proposal), 0);

      transfer::public_transfer(vote, bob);

      test::return_shared(proposal);      
    };

    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);
      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);
      clock::increment_for_testing(&mut c, DAO_VOTING_PERIOD + 1);

      assert_eq(dao::state(&proposal, &c), AGREED);

      let unstaked_coin = dao::unstake_vote<InterestDAO, S_ETH>(
        &proposal,
        vote,
        &c,
        ctx(test)
      );

      assert_eq(burn_for_testing(unstaked_coin), 1234567);
      assert_eq(dao::for_votes(&proposal), 1234567);
      assert_eq(dao::against_votes(&proposal), 0);

      test::return_shared(proposal);      
    };    

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EInvalidOTW)]
  fun test_no_otw_dao() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;  

    next_tx(test, alice);
    {
      let (dao, treasury) = dao::new<InterestDAO, S_ETH>(
        InterestDAO {},
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

    test::end(scenario);  
  }

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EInvalidQuorumRate)]
  fun test_zero_dao_quorum_rate() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;  

    next_tx(test, alice);
    {
      let (dao, treasury) = dao::new_for_testing<InterestDAO, S_ETH>(
        DAO_VOTING_DELAY,
        DAO_VOTING_PERIOD,
        0,
        DAO_MIN_ACTION_DELAY,
        DAO_MIN_QUORUM_VOTES,
        ctx(test)
      );
      
      transfer::public_share_object(dao);
      transfer::public_share_object(treasury);      
    };

    test::end(scenario);  
  }  

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EInvalidQuorumRate)]
  fun test_zero_dao_out_of_bounds_quorum_rate() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;  

    next_tx(test, alice);
    {
      let (dao, treasury) = dao::new_for_testing<InterestDAO, S_ETH>(
        DAO_VOTING_DELAY,
        DAO_VOTING_PERIOD,
        1_000_000_001,
        DAO_MIN_ACTION_DELAY,
        DAO_MIN_QUORUM_VOTES,
        ctx(test)
      );
      
      transfer::public_share_object(dao);
      transfer::public_share_object(treasury);      
    };

    test::end(scenario);  
  }

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EActionDelayTooShort)]
  fun test_proposal_low_action_delay() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        DAO_MIN_ACTION_DELAY - 1,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      transfer::public_share_object(proposal);
      test::return_shared(dao);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }    

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EMinQuorumVotesTooSmall)]
  fun test_proposal_low_quorum_votes() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        DAO_MIN_ACTION_DELAY,
        DAO_MIN_QUORUM_VOTES - 1,
        string::utf8(b"hash"),
        ctx(test)
      );

      transfer::public_share_object(proposal);
      test::return_shared(dao);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }       

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EEmptyHash)]
  fun test_proposal_no_hash() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        DAO_MIN_ACTION_DELAY,
        DAO_MIN_QUORUM_VOTES,
        string::utf8(b""),
        ctx(test)
      );

      transfer::public_share_object(proposal);
      test::return_shared(dao);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }   

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EProposalMustBeActive)]
  fun test_vote_on_pending_proposal() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up_with_proposal(test, &c);

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        true,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);   
    };

    clock::destroy_for_testing(c);
    test::end(scenario);          
  }  

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EProposalMustBeActive)]
  fun test_vote_on_defeated_proposal() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up_with_proposal(test, &c);

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, PROPOSAL_ACTION_DELAY + 1);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);   
    };

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_PERIOD + 1);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        true,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);   
    };

    clock::destroy_for_testing(c);
    test::end(scenario);          
  }    

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EInvalidCoinType)]
  fun test_vote_with_wrong_coin_type() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up_with_proposal(test, &c);

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, PROPOSAL_ACTION_DELAY + 1);

      let vote = dao::cast_vote<InterestDAO, SUI>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);   
    };

    clock::destroy_for_testing(c);
    test::end(scenario);          
  }     

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::ECannotVoteWithZeroCoinValue)]
  fun test_vote_with_zero_coin() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up_with_proposal(test, &c);

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, PROPOSAL_ACTION_DELAY + 1);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        coin::zero(ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);   
    };

    clock::destroy_for_testing(c);
    test::end(scenario);          
  } 

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EProposalMustBeActive)]
  fun test_change_vote_on_agreed_proposal() {
    let scenario = scenario();
    let (alice, bob) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up_with_proposal(test, &c);

    // 30 NO votes
    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(900, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, bob);

      test::return_shared(proposal);      
    };

    // 70 YES votes
    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        true,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);      
    };

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_PERIOD);

      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);

      dao::change_vote(
        &mut proposal,
        &mut vote,
        &c,
        ctx(test)
      );

      test::return_to_sender(test, vote);
      test::return_shared(proposal);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EVoteAndProposalIdMismatch)]
  fun test_change_vote_on_wrong_proposal() {
    let scenario = scenario();
    let (alice, bob) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    let proposal1_id;
    let proposal2_id;

    set_up(test);

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      
      clock::increment_for_testing(&mut c, 123);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      let proposal2 = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      proposal1_id = option::some(object::id(&proposal));
      proposal2_id = option::some(object::id(&proposal2));

      assert_eq(dao::state(&proposal, &c), PENDING);

      transfer::public_share_object(proposal);
      transfer::public_share_object(proposal2);
      test::return_shared(dao);      
    };

    // 30 NO votes
    next_tx(test, bob);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(900, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, bob);

      test::return_shared(proposal);      
    };

    // 70 YES votes
    next_tx(test, alice);
    {
      let proposal = test::take_shared_by_id<Proposal<InterestDAO>>(test, *option::borrow(& proposal1_id));

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        true,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);      
    };

    next_tx(test, alice);
    {
      let proposal = test::take_shared_by_id<Proposal<InterestDAO>>(test, *option::borrow(& proposal1_id));
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      let proposal2 = test::take_shared_by_id<Proposal<InterestDAO>>(test, *option::borrow(& proposal2_id));

      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);

      dao::change_vote(
        &mut proposal2,
        &mut vote,
        &c,
        ctx(test)
      );

      transfer::public_share_object(proposal2);
      test::return_to_sender(test, vote);
      test::return_shared(dao);
      test::return_shared(proposal);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EProposalMustBeActive)]
  fun test_revoke_vote_on_pending_proposal() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up_with_proposal(test, &c);

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        true,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);   
    };

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);
      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);

      burn_for_testing(dao::revoke_vote(
        &mut proposal,
        vote,
        &c,
        ctx(test)
      ));

      test::return_shared(proposal);  
    };    

    clock::destroy_for_testing(c);
    test::end(scenario);          
  }    

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EVoteAndProposalIdMismatch)]
  fun test_revoke_vote_on_wrong_proposal() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    let proposal1_id;
    let proposal2_id;

    set_up(test);

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      
      clock::increment_for_testing(&mut c, 123);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      let proposal2 = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      proposal1_id = option::some(object::id(&proposal));
      proposal2_id = option::some(object::id(&proposal2));

      assert_eq(dao::state(&proposal, &c), PENDING);

      transfer::public_share_object(proposal);
      transfer::public_share_object(proposal2);
      test::return_shared(dao);      
    };

    // 30 NO votes
    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(900, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);      
    };

    next_tx(test, alice);
    {
      let proposal = test::take_shared_by_id<Proposal<InterestDAO>>(test, *option::borrow(& proposal1_id));
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      let proposal2 = test::take_shared_by_id<Proposal<InterestDAO>>(test, *option::borrow(& proposal2_id));

      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);

      burn_for_testing(dao::revoke_vote(
        &mut proposal,
        vote, 
        &c,
        ctx(test)
      ));

      transfer::public_share_object(proposal2);
      test::return_shared(dao);
      test::return_shared(proposal);      
    };

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }  

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EProposalMustBeActive)]
  fun test_unstake_vote_on_pending_proposal() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up_with_proposal(test, &c);

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(2100, ctx(test)),
        true,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);   
    };

    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);
      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);

      clock::increment_for_testing(&mut c, PROPOSAL_ACTION_DELAY + 1);

      burn_for_testing(dao::unstake_vote(
        &proposal,
        vote,
        &c,
        ctx(test)
      ));

      test::return_shared(proposal);  
    };    

    clock::destroy_for_testing(c);
    test::end(scenario);          
  }      

  #[test]  
  #[lint_allow(share_owned)]
  #[expected_failure(abort_code = dao::EVoteAndProposalIdMismatch)]
  fun test_unstake_vote_on_wrong_proposal() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    let proposal1_id;
    let proposal2_id;

    set_up(test);

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      
      clock::increment_for_testing(&mut c, 123);

      let proposal = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      let proposal2 = dao::propose(
        &mut dao,
        &c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      proposal1_id = option::some(object::id(&proposal));
      proposal2_id = option::some(object::id(&proposal2));

      assert_eq(dao::state(&proposal, &c), PENDING);

      transfer::public_share_object(proposal);
      transfer::public_share_object(proposal2);
      test::return_shared(dao);      
    };

    // 30 NO votes
    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);

      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      assert_eq(dao::state(&proposal, &c), ACTIVE);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(900, ctx(test)),
        false,
        ctx(test)
      );

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);      
    };

    next_tx(test, alice);
    {
      let proposal = test::take_shared_by_id<Proposal<InterestDAO>>(test, *option::borrow(& proposal1_id));
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      let proposal2 = test::take_shared_by_id<Proposal<InterestDAO>>(test, *option::borrow(& proposal2_id));

      clock::increment_for_testing(&mut c, DAO_VOTING_PERIOD + 1);

      let vote = test::take_from_sender<Vote<InterestDAO, S_ETH>>(test);

      burn_for_testing(dao::unstake_vote(
        &proposal,
        vote, 
        &c,
        ctx(test)
      ));

      transfer::public_share_object(proposal2);
      test::return_shared(dao);
      test::return_shared(proposal);      
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

  #[lint_allow(share_owned)]
  fun set_up_with_proposal(test: &mut Scenario, c: &Clock) {

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

    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);

      let proposal = dao::propose(
        &mut dao,
        c,
        option::none(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        string::utf8(b"hash"),
        ctx(test)
      );

      transfer::public_share_object(proposal);
      test::return_shared(dao);  
    };
  }

}
