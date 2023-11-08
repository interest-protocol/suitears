// Based from https://github.com/starcoinorg/starcoin-framework/blob/main/sources/Dao.move
// Before creating a DAO make sure your tokens are properly distributed
// Do not add capabilities to hot potatoes (see https://docs.sui.io/concepts/sui-move-concepts/patterns/hot-potato)
module suitears::dao {
  use std::vector;
  use std::option::{Self, Option};
  use std::type_name::{get, TypeName};

  use sui::event::emit;
  use sui::coin::{Self, Coin};
  use sui::clock::{Self, Clock};
  use sui::vec_set::{Self, VecSet};
  use sui::object::{Self, ID, UID};
  use sui::balance::{Self, Balance};
  use sui::types::is_one_time_witness;
  use sui::tx_context::{Self, TxContext};

  use suitears::dao_action::{Self, Action};
  use suitears::dao_treasury::{Self, DaoTreasury};
  use suitears::fixed_point_roll::{roll, roll_div_down};

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
  const EInvalidVotingDelay: u64 = 2;
  const EInvalidVotingPeriod: u64 = 3;
  const EInvalidMinActionDelay: u64 = 4;
  const EActionDelayTooSmall: u64 = 5;
  const EInvalidMinQuorumVotes: u64 = 6;
  const EMinQuorumVotesTooSmall: u64 = 7;
  const EProposalMustBeActive: u64 = 8;
  const ECannotVoteWithZeroCoinValue: u64 = 9;
  const ECannotUnstakeFromAnActiveProposal: u64 = 10;
  const EVoteAndProposalIdMismatch: u64 = 11;
  const ECannotExecuteThisProposal: u64 = 12;
  const ETooEarlyToExecute: u64 = 13;
  const EEmptyHash: u64 = 14;

  // Generic Struct represents null/undefined
  struct Nothing has drop, copy, store {}

  struct DaoActionWitness has drop {}

  struct DaoConfig has store, copy, drop {
    voting_delay: Option<u64>,
    voting_period: Option<u64>,
    voting_quorum_rate: Option<u128>,
    min_action_delay: Option<u64>,
    min_quorum_votes: Option<u64>    
  }

  struct Rules<T: store> has key, store {
    id: UID,
    rules: VecSet<TypeName>,
    payload: T
  }

  struct Dao<phantom OTW, phantom CoinType> has key, store {
    id: UID,
    /// after proposal created, how long use should wait before he can vote (in milliseconds)
    voting_delay: u64,
    /// how long the voting window is (in milliseconds).
    voting_period: u64,
    /// the quorum rate to agree on the proposal.
    /// if 50% votes needed, then the voting_quorum_rate should be 50.
    /// it should between (0, 100 wad].
    voting_quorum_rate: u128,
    /// how long the proposal should wait before it can be executed (in milliseconds).
    min_action_delay: u64,
    min_quorum_votes: u64,
    treasury: Option<ID>
  }

  struct Proposal<phantom DaoWitness: drop, phantom CoinType, T: store> has key, store {
    id: UID,
    proposer: address,
    start_time: u64,
    end_time: u64,
    for_votes: u64,
    against_votes: u64,
    eta: u64,
    action_delay: u64,
    quorum_votes: u64,
    voting_quorum_rate: u128, 
    rules: Option<Rules<T>>,
    hash: vector<u8>
  }

  struct Vote<phantom DaoWitness: drop, phantom CoinType, phantom T> has  key, store {
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
    voting_quorum_rate: u128, 
    min_action_delay: u64, 
    min_quorum_votes: u64
  }

  struct UpdateDao<phantom OTW, phantom CoinType> has copy, drop {
    dao_id: ID,
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u128, 
    min_action_delay: u64, 
    min_quorum_votes: u64
  }

  struct NewProposal<phantom DaoWitness, phantom CoinType, phantom T> has copy, drop {
    proposal_id: ID,
    proposer: address,
  }

  struct CastVote<phantom DaoWitness, phantom CoinType, phantom T> has copy, drop {
    voter: address, 
    proposal_id: ID,
    agree: bool,
    end_time: u64,
    value: u64
  }

  struct ChangeVote<phantom DaoWitness, phantom CoinType, phantom T> has copy, drop {
    voter: address, 
    proposal_id: ID,
    vote_id: ID,
    agree: bool,
    end_time: u64,
    value: u64
  }

  struct RevokeVote<phantom DaoWitness, phantom CoinType, phantom T> has copy, drop {
    voter: address, 
    proposal_id: ID,
    agree: bool,
    value: u64
  }

  struct UnstakeVote<phantom DaoWitness, phantom CoinType, phantom T> has copy, drop {
    voter: address, 
    proposal_id: ID,
    agree: bool,
    value: u64
  }

  public fun create<OTW: drop, CoinType>(
    otw: OTW, 
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u128, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    ctx: &mut TxContext
  ): Dao<OTW, CoinType> {
    assert!(is_one_time_witness(&otw), EInvalidOTW);

    let dao = Dao<OTW, CoinType> {
      id: object::new(ctx),
      voting_delay,
      voting_period,
      voting_quorum_rate,
      min_action_delay,
      min_quorum_votes,
      treasury: option::none()
    };

    assert_dao_config(&dao);

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
    voting_quorum_rate: u128, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    allow_flashloan: bool,
    ctx: &mut TxContext
  ): (Dao<OTW, CoinType>, DaoTreasury<OTW>) {
    let dao = create<OTW, CoinType>(otw, voting_delay, voting_period, voting_quorum_rate, min_action_delay, min_quorum_votes, ctx);

    let treasury = dao_treasury::create<OTW>(object::id(&dao), allow_flashloan, ctx);

    option::fill(&mut dao.treasury, object::id(&treasury));
    
    (
      dao,
      treasury
    )
  }

  public fun propose_with_action<DaoWitness: drop, CoinType, T: store>(
    dao: &mut Dao<DaoWitness, CoinType>,
    c: &Clock,
    rules: Rules<T>,
    action_delay: u64,
    min_quorum_votes: u64,
    hash: vector<u8>,//
    ctx: &mut TxContext
  ): Proposal<DaoWitness, CoinType, T> {
   propose(dao, c, option::some(rules), action_delay, min_quorum_votes, hash, ctx)
  }

  public fun propose_without_action<DaoWitness: drop, CoinType>(
    dao: &mut Dao<DaoWitness, CoinType>,
    c: &Clock,
    action_delay: u64,
    min_quorum_votes: u64,
    hash: vector<u8>,//
    ctx: &mut TxContext
  ): Proposal<DaoWitness, CoinType, Nothing> {
   propose(dao, c, option::none(), action_delay, min_quorum_votes, hash, ctx)
  }

  public fun create_rules<T: store>(payload: T, ctx: &mut TxContext): Rules<T> {
    Rules {
      id: object::new(ctx),
      rules: vec_set::empty(),
      payload
    }
  }

  public fun add_rule<T: store, Rule>(rules: &mut Rules<T>) {
    vec_set::insert(&mut rules.rules, get<Rule>());
  }

  public fun cast_vote<DaoWitness: drop, CoinType, T: store>(
    proposal: &mut Proposal<DaoWitness, CoinType, T>,
    c: &Clock,
    stake: Coin<CoinType>,
    agree: bool,
    ctx: &mut TxContext
  ): Vote<DaoWitness, CoinType, T> {
    assert!(get_proposal_state(proposal, clock::timestamp_ms(c)) == ACTIVE, EProposalMustBeActive);

    let value = coin::value(&stake);
    assert!(value != 0, ECannotVoteWithZeroCoinValue);

    if (agree) proposal.for_votes = proposal.for_votes + value else proposal.against_votes = proposal.against_votes + value;

    let proposal_id = object::id(proposal);

    emit(CastVote<DaoWitness,  CoinType, T>{ proposal_id: proposal_id, value, voter: tx_context::sender(ctx), end_time: proposal.end_time, agree });

    Vote {
      id: object::new(ctx),
      agree,
      balance: coin::into_balance(stake),
      end_time: proposal.end_time,
      proposal_id: proposal_id
    }
  }

  public fun change_vote<DaoWitness: drop, CoinType, T: store>(
    proposal: &mut Proposal<DaoWitness,  CoinType, T>,
    vote: &mut Vote<DaoWitness,  CoinType, T>,
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

    emit(ChangeVote<DaoWitness,  CoinType, T>{ proposal_id, value, voter: tx_context::sender(ctx), end_time: proposal.end_time, agree: vote.agree, vote_id: object::id(vote) });
  }

  public fun revoke_vote<DaoWitness: drop, CoinType, T: store>(
    proposal: &mut Proposal<DaoWitness,  CoinType, T>,
    vote: Vote<DaoWitness, CoinType, T>,
    c: &Clock,
    ctx: &mut TxContext    
  ): Coin<CoinType> {
    assert!(get_proposal_state(proposal, clock::timestamp_ms(c)) == ACTIVE, EProposalMustBeActive);
    let proposal_id = object::id(proposal);
    assert!(proposal_id == vote.proposal_id, EVoteAndProposalIdMismatch);

    let value = balance::value(&vote.balance);
    if (vote.agree) proposal.for_votes = proposal.for_votes - value else proposal.against_votes = proposal.against_votes - value;

    emit(RevokeVote<DaoWitness,  CoinType, T>{ proposal_id: proposal_id, value, agree: vote.agree, voter: tx_context::sender(ctx) });

    destroy_vote(vote, ctx)
  }

  public fun unstake_vote<DaoWitness: drop, CoinType, T: store>(
    proposal: &Proposal<DaoWitness, CoinType, T>,
    vote: Vote<DaoWitness, CoinType, T>,
    c: &Clock,
    ctx: &mut TxContext      
  ): Coin<CoinType> {
    // Everything greater than active can be unstaked 
    assert!(get_proposal_state(proposal, clock::timestamp_ms(c)) > ACTIVE, ECannotUnstakeFromAnActiveProposal);
    let proposal_id = object::id(proposal);
    assert!(proposal_id == vote.proposal_id, EVoteAndProposalIdMismatch);

    emit(UnstakeVote<DaoWitness, CoinType, T>{ proposal_id: proposal_id, value: balance::value(&vote.balance), agree: vote.agree, voter: tx_context::sender(ctx) });

    destroy_vote(vote, ctx)
  }

  public fun execute_proposal<DaoWitness: drop, CoinType, T: store>(
    proposal: &mut Proposal<DaoWitness, CoinType, T>, 
    c: &Clock
  ): Action<DaoWitness, CoinType, T> {
    let now = clock::timestamp_ms(c);
    assert!(get_proposal_state(proposal, now) == EXECUTABLE, ECannotExecuteThisProposal);
    assert!(now >= proposal.end_time + proposal.action_delay, ETooEarlyToExecute);

    let rules = option::extract(&mut proposal.rules);

    let Rules { id, payload, rules } = rules;

    object::delete(id);

    dao_action::create(rules, payload)
  }

  public fun proposal_state<DaoWitness: drop, CoinType, T: store>(proposal: &Proposal<DaoWitness, CoinType, T>, c: &Clock): u8 {
    get_proposal_state(proposal, clock::timestamp_ms(c))
  }

  public fun view_vote<DaoWitness: drop, CoinType, T: store>(
    vote: &Vote<DaoWitness, CoinType, T>
  ): (ID, ID, u64, bool, u64) {
    (object::id(vote), vote.proposal_id, balance::value(&vote.balance), vote.agree, vote.end_time)
  }

  public fun view_proposal<DaoWitness: drop, CoinType, T: store>(
    proposal: &Proposal<DaoWitness,  CoinType, T>, 
    c: &Clock
  ): (ID, address, u8, u64, u64, u64, u64, u64, u64, u64, vector<u8>, &Option<Rules<T>>) {
    (object::id(proposal), proposal.proposer, proposal_state(proposal, c), proposal.start_time, proposal.end_time, proposal.for_votes, proposal.against_votes, proposal.eta, proposal.action_delay, proposal.quorum_votes, proposal.hash, &proposal.rules)
  }

  fun propose<DaoWitness: drop, CoinType, T: store>(
    dao: &mut Dao<DaoWitness, CoinType>,
    c: &Clock,
    rules: Option<Rules<T>>,
    action_delay: u64,
    quorum_votes: u64,
    hash: vector<u8>,// hash proposal title/content
    ctx: &mut TxContext    
  ): Proposal<DaoWitness, CoinType, T> {
    assert!(action_delay >= dao.min_action_delay, EActionDelayTooSmall);
    assert!(quorum_votes >= dao.min_quorum_votes, EMinQuorumVotesTooSmall);
    assert!(vector::length(&hash) != 0, EEmptyHash);

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
      rules
    };
    
    emit(NewProposal<DaoWitness, CoinType, T> { proposal_id: object::id(&proposal), proposer: proposal.proposer });

    proposal
  }

  fun destroy_vote<DaoWitness: drop, CoinType, T: store>(vote: Vote<DaoWitness, CoinType, T>, ctx: &mut TxContext): Coin<CoinType> {
    let Vote {id, balance, agree: _, end_time: _, proposal_id: _} = vote;
    object::delete(id);

    coin::from_balance(balance, ctx)
  }

  fun get_proposal_state<DaoWitness: drop, CoinType, T: store>(
    proposal: &Proposal<DaoWitness, CoinType, T>,
    current_time: u64,
  ): u8 {
    if (current_time < proposal.start_time) {
      // Pending
      PENDING
    } else if (current_time <= proposal.end_time) {
      // Active
      ACTIVE
    } else if (proposal.for_votes <= proposal.against_votes ||
      proposal.for_votes < proposal.quorum_votes || proposal.voting_quorum_rate > roll_div_down((proposal.for_votes as u128), ((proposal.for_votes + proposal.against_votes) as u128)) ) {
      // Defeated
      DEFEATED
    } else if (proposal.eta == 0) {
      // Agreed.
      AGREED
    } else if (current_time < proposal.eta) {
      // Queued, waiting to execute
      QUEUED
    } else if (option::is_some(&proposal.rules)) {
      EXECUTABLE
    } else {
      EXTRACTED
    }
  }

  fun assert_dao_config<DaoWitness: drop, CoinType>(dao: &Dao<DaoWitness, CoinType>) {
    assert!(100 * roll() >= dao.voting_quorum_rate && dao.voting_quorum_rate != 0, EInvalidQuorumRate);
    assert!(dao.voting_delay != 0, EInvalidVotingDelay);
    assert!(dao.voting_period != 0, EInvalidVotingPeriod);
    assert!(dao.min_action_delay != 0, EInvalidMinActionDelay);
    assert!(dao.min_quorum_votes != 0, EInvalidMinQuorumVotes);
  }

  
   // Only Proposal can update Dao settings

   public fun make_dao_config(
    voting_delay: u64,
    voting_period: u64,
    voting_quorum_rate: u128,
    min_action_delay: u64,
    min_quorum_votes: u64
   ): DaoConfig {
    DaoConfig {
      voting_delay: if (voting_delay == 0)  option::none() else option::some(voting_delay),
      voting_period: if (voting_period == 0) option::none() else option::some(voting_period),
      voting_quorum_rate:  if (voting_quorum_rate == 0) option::none() else option::some(voting_quorum_rate),
      min_action_delay: if (min_action_delay == 0) option::none() else option::some(min_action_delay),
      min_quorum_votes: if (min_quorum_votes == 0) option::none() else option::some(min_quorum_votes),
    }
   } 

   public fun update_dao_config<DaoWitness: drop, CoinType>(
    dao: &mut Dao<DaoWitness, CoinType>,
    action: Action<DaoWitness, CoinType, DaoConfig>
   ) {

    dao_action::complete_rule(DaoActionWitness {}, &mut action);
    let payload = dao_action::finish_action(action);

    let DaoConfig { voting_delay, voting_period, voting_quorum_rate, min_action_delay, min_quorum_votes  } = payload;

    dao.voting_delay = option::destroy_with_default(voting_delay, dao.voting_delay);
    dao.voting_period = option::destroy_with_default(voting_period, dao.voting_period);
    dao.voting_quorum_rate = option::destroy_with_default(voting_quorum_rate, dao.voting_quorum_rate);
    dao.min_action_delay = option::destroy_with_default(min_action_delay, dao.min_action_delay);
    dao.min_quorum_votes = option::destroy_with_default(min_quorum_votes, dao.min_quorum_votes);

    assert_dao_config(dao);

    emit(
      UpdateDao<DaoWitness, CoinType> {
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