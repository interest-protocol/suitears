// Based from https://github.com/starcoinorg/starcoin-framework/blob/main/sources/Dao.move
// Before creating a DAO make sure your tokens are properly distributed
// Do not add capabilities to hot potatoes (see https://docs.sui.io/concepts/sui-move-concepts/patterns/hot-potato)
module suitears::dao {
  use std::vector;
  use std::option::{Self, Option};
  use std::type_name::{Self, TypeName};

  use sui::vec_set;
  use sui::event::emit;
  use sui::coin::{Self, Coin};
  use sui::clock::{Self, Clock};
  use sui::object::{Self, ID, UID};
  use sui::balance::{Self, Balance};
  use sui::types::is_one_time_witness;
  use sui::tx_context::{Self, TxContext};

  use suitears::dao_potato::{Self, DaoPotato};
  use suitears::dao_treasury::{Self, DaoTreasury};
  use suitears::fixed_point_roll::div_down;
  use suitears::request::{Self, RequestPotato, Request};

  /// Proposal state
  const PENDING: u8 = 1;
  const ACTIVE: u8 = 2;
  const DEFEATED: u8 = 3;
  const AGREED: u8 = 4;
  const QUEUED: u8 = 5;
  const EXECUTABLE: u8 = 6;
  const EXTRACTED: u8 = 7;

  const EInvalidOTW: u64 = 0;
  const EInvalidQuorumRate: u64 = 1;
  const EActionDelayTooSmall: u64 = 5;
  const EMinQuorumVotesTooSmall: u64 = 7;
  const EProposalMustBeActive: u64 = 8;
  const ECannotVoteWithZeroCoinValue: u64 = 9;
  const ECannotUnstakeFromAnActiveProposal: u64 = 10;
  const EVoteAndProposalIdMismatch: u64 = 11;
  const ECannotExecuteThisProposal: u64 = 12;
  const ETooEarlyToExecute: u64 = 13;
  const EEmptyHash: u64 = 14;
  const EProposalNotPassed: u64 = 15;
  const EInvalidCoinType: u64 = 16;

  struct Config has store {
    voting_delay: Option<u64>,
    voting_period: Option<u64>,
    voting_quorum_rate: Option<u64>,
    min_action_delay: Option<u64>,
    min_quorum_votes: Option<u64>    
  }

  struct ConfigTask has drop {}

  struct Dao<phantom OTW> has key, store {
    id: UID,
    /// after proposal created, how long user should wait before being able to vote (in milliseconds)
    voting_delay: u64,
    /// how long the voting window is (in milliseconds).
    voting_period: u64,
    /// the quorum rate to agree on the proposal.
    /// if 50% votes needed, then the voting_quorum_rate should be 50.
    /// it should between (0, 100 * 1e9].
    voting_quorum_rate: u64,
    /// how long the proposal should wait before it can be executed (in milliseconds).
    min_action_delay: u64,
    min_quorum_votes: u64,
    treasury: Option<ID>,
    coin_type: TypeName
  }

  struct Proposal<phantom DaoWitness: drop> has key, store {
    id: UID,
    proposer: address,
    start_time: u64, // when voting begins
    end_time: u64, // when voting ends
    for_votes: u64,
    against_votes: u64,
    eta: u64, // executable after this time
    action_delay: u64, // after how long, the agreed proposal can be executed.
    quorum_votes: u64, // the number of votes to pass the proposal.
    voting_quorum_rate: u64, 
    requests: vector<Request>,
    hash: vector<u8>,
    coin_type: TypeName
  }

  struct Vote<phantom DaoWitness: drop, phantom CoinType> has  key, store {
    id: UID,
    balance: Balance<CoinType>,
    proposal_id: ID,
    end_time: u64,
    agree: bool
  } 

  // Events

  struct CreateDao<phantom OTW, phantom CoinType> has copy, drop {
    dao_id: ID,
    creator: address,
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u64, 
    min_action_delay: u64, 
    min_quorum_votes: u64
  }

  struct UpdateDao<phantom OTW> has copy, drop {
    dao_id: ID,
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u64, 
    min_action_delay: u64, 
    min_quorum_votes: u64
  }

  struct NewProposal<phantom DaoWitness> has copy, drop {
    proposal_id: ID,
    proposer: address,
  }

  struct CastVote<phantom DaoWitness, phantom CoinType> has copy, drop {
    voter: address, 
    proposal_id: ID,
    agree: bool,
    end_time: u64,
    value: u64
  }

  struct ChangeVote<phantom DaoWitness, phantom CoinType> has copy, drop {
    voter: address, 
    proposal_id: ID,
    vote_id: ID,
    agree: bool,
    end_time: u64,
    value: u64
  }

  struct RevokeVote<phantom DaoWitness, phantom CoinType> has copy, drop {
    voter: address, 
    proposal_id: ID,
    agree: bool,
    value: u64
  }

  struct UnstakeVote<phantom DaoWitness, phantom CoinType> has copy, drop {
    voter: address, 
    proposal_id: ID,
    agree: bool,
    value: u64
  }

  public fun create<OTW: drop, CoinType>(
    otw: OTW, 
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u64, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    ctx: &mut TxContext
  ): Dao<OTW> {
    assert!(is_one_time_witness(&otw), EInvalidOTW);
    assert!(100 * 1_000_000_000 >= voting_quorum_rate && voting_quorum_rate != 0, EInvalidQuorumRate);

    let dao = Dao<OTW> {
      id: object::new(ctx),
      voting_delay,
      voting_period,
      voting_quorum_rate,
      min_action_delay,
      min_quorum_votes,
      treasury: option::none(),
      coin_type: type_name::get<CoinType>()
    };

    emit(
      CreateDao<OTW, CoinType> {
        dao_id: object::id(&dao),
        creator: tx_context::sender(ctx),
        voting_delay,
        voting_period,
        voting_quorum_rate,
        min_action_delay,
        min_quorum_votes
      }
    );

    dao
  }

  // ** Important Make sure the voting_period and min_quorum_votes is adequate because a large holder can vote to withdraw all coins from the treasury.
  // ** Also major stakeholders should monitor all proposals to ensure they vote against malicious proposals.
  public fun create_with_treasury<OTW: drop, CoinType>(
    otw: OTW, 
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u64, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    allow_flashloan: bool,
    ctx: &mut TxContext
  ): (Dao<OTW>, DaoTreasury<OTW>) {
    let dao = create<OTW, CoinType>(otw, voting_delay, voting_period, voting_quorum_rate, min_action_delay, min_quorum_votes, ctx);
    let treasury = dao_treasury::create<OTW>(object::id(&dao), allow_flashloan, ctx);

    option::fill(&mut dao.treasury, object::id(&treasury));
    
    (dao, treasury)
  }

  public fun propose<DaoWitness: drop>(
    dao: &mut Dao<DaoWitness>,
    c: &Clock,
    requests: vector<Request>,
    action_delay: u64,
    quorum_votes: u64,
    hash: vector<u8>,// hash proposal title/content
    ctx: &mut TxContext    
  ): Proposal<DaoWitness> {
    assert!(action_delay >= dao.min_action_delay, EActionDelayTooSmall);
    assert!(quorum_votes >= dao.min_quorum_votes, EMinQuorumVotesTooSmall);
    assert!(vector::length(&hash) != 0, EEmptyHash);

    // @dev To make sure the tasks are unique
    let num_of_requests = vector::length(&requests);
    let index = 0;
    let set = vec_set::empty();


    while (num_of_requests > index) {
      let req = vector::borrow(&requests, index);

      vec_set::insert(&mut set, request::request_name(req));  

      index = index + 1;
    };

    let start_time = clock::timestamp_ms(c) + dao.voting_delay;

    let proposal = Proposal {
      id: object::new(ctx),
      proposer: tx_context::sender(ctx),
      start_time,
      end_time: start_time + dao.voting_period,
      for_votes: 0,
      against_votes: 0,
      eta: 0,
      action_delay,
      quorum_votes,
      voting_quorum_rate: dao.voting_quorum_rate,
      hash,
      requests,
      coin_type: dao.coin_type
    };
    
    emit(NewProposal<DaoWitness> { proposal_id: object::id(&proposal), proposer: proposal.proposer });

    proposal
  }

  public fun cast_vote<DaoWitness: drop, CoinType>(
    proposal: &mut Proposal<DaoWitness>,
    c: &Clock,
    stake: Coin<CoinType>,
    agree: bool,
    ctx: &mut TxContext
  ): Vote<DaoWitness, CoinType> {
    assert!(get_proposal_state(proposal, clock::timestamp_ms(c)) == ACTIVE, EProposalMustBeActive);
    assert!(proposal.coin_type == type_name::get<CoinType>(), EInvalidCoinType);

    let value = coin::value(&stake);
    assert!(value != 0, ECannotVoteWithZeroCoinValue);

    if (agree) proposal.for_votes = proposal.for_votes + value else proposal.against_votes = proposal.against_votes + value;

    let proposal_id = object::id(proposal);

    emit(CastVote<DaoWitness,  CoinType>{ proposal_id: proposal_id, value, voter: tx_context::sender(ctx), end_time: proposal.end_time, agree });

    Vote {
      id: object::new(ctx),
      agree,
      balance: coin::into_balance(stake),
      end_time: proposal.end_time,
      proposal_id
    }
  }

  public fun change_vote<DaoWitness: drop, CoinType>(
    proposal: &mut Proposal<DaoWitness>,
    vote: &mut Vote<DaoWitness,  CoinType>,
    c: &Clock,
    ctx: &mut TxContext
  ) {
    assert!(get_proposal_state(proposal, clock::timestamp_ms(c)) == ACTIVE, EProposalMustBeActive);
    let proposal_id = object::id(proposal);
    assert!(proposal_id == vote.proposal_id, EVoteAndProposalIdMismatch);
    let value = balance::value(&vote.balance);

    vote.agree = !vote.agree;

    if (vote.agree) {
      proposal.against_votes = proposal.against_votes - value;
      proposal.for_votes = proposal.for_votes + value;
    } else {
      proposal.for_votes = proposal.for_votes - value;
      proposal.against_votes = proposal.against_votes + value;
    };

    emit(ChangeVote<DaoWitness,  CoinType>{ proposal_id, value, voter: tx_context::sender(ctx), end_time: proposal.end_time, agree: vote.agree, vote_id: object::id(vote) });
  }

  public fun revoke_vote<DaoWitness: drop, CoinType>(
    proposal: &mut Proposal<DaoWitness>,
    vote: Vote<DaoWitness, CoinType>,
    c: &Clock,
    ctx: &mut TxContext    
  ): Coin<CoinType> {
    assert!(get_proposal_state(proposal, clock::timestamp_ms(c)) == ACTIVE, EProposalMustBeActive);
    let proposal_id = object::id(proposal);
    assert!(proposal_id == vote.proposal_id, EVoteAndProposalIdMismatch);

    let value = balance::value(&vote.balance);
    if (vote.agree) proposal.for_votes = proposal.for_votes - value else proposal.against_votes = proposal.against_votes - value;

    emit(RevokeVote<DaoWitness,  CoinType>{ proposal_id: proposal_id, value, agree: vote.agree, voter: tx_context::sender(ctx) });

    destroy_vote(vote, ctx)
  }

  public fun unstake_vote<DaoWitness: drop, CoinType>(
    proposal: &Proposal<DaoWitness>,
    vote: Vote<DaoWitness, CoinType>,
    c: &Clock,
    ctx: &mut TxContext      
  ): Coin<CoinType> {
    // Everything greater than active can be unstaked 
    assert!(get_proposal_state(proposal, clock::timestamp_ms(c)) > ACTIVE, ECannotUnstakeFromAnActiveProposal);
    let proposal_id = object::id(proposal);
    assert!(proposal_id == vote.proposal_id, EVoteAndProposalIdMismatch);

    emit(UnstakeVote<DaoWitness, CoinType>{ proposal_id: proposal_id, value: balance::value(&vote.balance), agree: vote.agree, voter: tx_context::sender(ctx) });

    destroy_vote(vote, ctx)
  }

  public fun queue_proposal<DaoWitness: drop>(
    proposal: &mut Proposal<DaoWitness>, 
    c: &Clock
  ) {
    // Only agreed proposal can be submitted.
    let now = clock::timestamp_ms(c);
    assert!(get_proposal_state(proposal, now) == AGREED, EProposalNotPassed);
    proposal.eta = now + proposal.action_delay;
  }

  public fun execute_proposal<DaoWitness: drop>(
    proposal: &mut Proposal<DaoWitness>, 
    c: &Clock
  ): RequestPotato<DaoPotato<DaoWitness>> {
    let now = clock::timestamp_ms(c);
    assert!(get_proposal_state(proposal, now) == EXECUTABLE, ECannotExecuteThisProposal);
    assert!(now >= proposal.end_time + proposal.action_delay, ETooEarlyToExecute);

    let potato = dao_potato::new();

    let num_of_requests = vector::length(&proposal.requests);
    let index = 0;

    while (num_of_requests > index) {
      request::add_request(&mut potato, vector::remove(&mut proposal.requests, 0));

      index = index + 1;
    };

    potato
  }

  public fun proposal_state<DaoWitness: drop>(proposal: &Proposal<DaoWitness>, c: &Clock): u8 {
    get_proposal_state(proposal, clock::timestamp_ms(c))
  }

  public fun view_vote<DaoWitness: drop, CoinType>(
    vote: &Vote<DaoWitness, CoinType>
  ): (ID, ID, u64, bool, u64) {
    (object::id(vote), vote.proposal_id, balance::value(&vote.balance), vote.agree, vote.end_time)
  }

  public fun view_proposal<DaoWitness: drop>(
    proposal: &Proposal<DaoWitness>, 
    c: &Clock
  ): (ID, address, u8, u64, u64, u64, u64, u64, u64, u64, vector<u8>, &vector<Request>, TypeName) {
    (object::id(proposal), proposal.proposer, proposal_state(proposal, c), proposal.start_time, proposal.end_time, proposal.for_votes, proposal.against_votes, proposal.eta, proposal.action_delay, proposal.quorum_votes, proposal.hash, &proposal.requests, proposal.coin_type)
  }

  fun destroy_vote<DaoWitness: drop, CoinType>(vote: Vote<DaoWitness, CoinType>, ctx: &mut TxContext): Coin<CoinType> {
    let Vote {id, balance, agree: _, end_time: _, proposal_id: _} = vote;
    object::delete(id);

    coin::from_balance(balance, ctx)
  }

  fun get_proposal_state<DaoWitness: drop>(
    proposal: &Proposal<DaoWitness>,
    current_time: u64,
  ): u8 {
    if (current_time < proposal.start_time) {
      // Pending
      PENDING
    } else if (current_time <= proposal.end_time) {
      // Active
      ACTIVE
    } else if (
      proposal.for_votes <= proposal.against_votes ||
      proposal.for_votes < proposal.quorum_votes || 
      proposal.voting_quorum_rate > div_down(proposal.for_votes, proposal.for_votes + proposal.against_votes)
    ) {
      // Defeated
      DEFEATED
    } else if (proposal.eta == 0) {
      // Agreed.
      AGREED
    } else if (current_time < proposal.eta) {
      // Queued, waiting to execute
      QUEUED
    } else if (!vector::is_empty(&proposal.requests)) {
      EXECUTABLE
    } else {
      EXTRACTED
    }
  }
  
   // Only Proposal can update Dao settings

  public fun make_dao_config(
    voting_delay: Option<u64>, 
    voting_period: Option<u64>, 
    voting_quorum_rate: Option<u64>, 
    min_action_delay: Option<u64>, 
    min_quorum_votes: Option<u64>
  ): Config {
    Config { 
      voting_delay, 
      voting_period, 
      voting_quorum_rate, 
      min_action_delay, 
      min_quorum_votes 
    }
  } 

  public fun update_dao_config<DaoWitness: drop>(
    dao: &mut Dao<DaoWitness>,
    potato: RequestPotato<DaoPotato<DaoWitness>>
  ) {
    let Config { 
      voting_delay, 
      voting_period, 
      voting_quorum_rate, 
      min_action_delay, 
      min_quorum_votes  
    } = request::complete_request_with_payload<DaoPotato<DaoWitness>, ConfigTask, Config>(ConfigTask {}, &mut potato);

    request::destroy_potato(potato);

    dao.voting_delay = option::destroy_with_default(voting_delay, dao.voting_delay);
    dao.voting_period = option::destroy_with_default(voting_period, dao.voting_period);
    dao.voting_quorum_rate = option::destroy_with_default(voting_quorum_rate, dao.voting_quorum_rate);
    dao.min_action_delay = option::destroy_with_default(min_action_delay, dao.min_action_delay);
    dao.min_quorum_votes = option::destroy_with_default(min_quorum_votes, dao.min_quorum_votes);

    assert!(100 * 1_000_000_000 >= dao.voting_quorum_rate && dao.voting_quorum_rate != 0, EInvalidQuorumRate);

    emit(
      UpdateDao<DaoWitness> {
        dao_id: object::id(dao),
        voting_delay: dao.voting_delay,
        voting_period: dao.voting_period,
        voting_quorum_rate: dao.voting_quorum_rate,
        min_action_delay: dao.min_action_delay,
        min_quorum_votes: dao.min_quorum_votes
      }
    );
  }
}