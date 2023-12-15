/*
* @title Decentralized Autonomous Organization
*
* @notice It allows anyone to create a DAO, submit proposals and execute actions on-chain.    
*
* @dev It was inspired from https://github.com/starcoinorg/starcoin-framework/blob/main/sources/Dao.move.  
*/
module suitears::dao {
  use std::vector;
  use std::option::{Self, Option};
  use std::type_name::{Self, TypeName};

  use sui::event::emit;
  use sui::coin::{Self, Coin};
  use sui::clock::{Self, Clock};
  use sui::object::{Self, ID, UID};
  use sui::balance::{Self, Balance};
  use sui::types::is_one_time_witness;
  use sui::transfer::{Self, Receiving};
  use sui::tx_context::{Self, TxContext};

  use suitears::fixed_point_roll::div_down; 
  use suitears::dao_admin::{Self, DaoAdmin};
  use suitears::dao_treasury::{Self, DaoTreasury};

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
  const EInvalidExecuteWitness: u64 = 17;
  const EInvalidExecuteCapability: u64 = 18;
  const EInvalidReturnCapability: u64 = 19;
  const EInvalidReturnDAO: u64 = 20;

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
    hash: vector<u8>,
    authorized_witness: TypeName,
    capability_id: Option<ID>,
    coin_type: TypeName
  }

  struct CapabilityReceipt {
    capability_id: ID,
    dao_id: ID
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
    admin_id: ID,
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

  public fun new<OTW: drop, CoinType>(
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

    let admin = dao_admin::new<OTW>(ctx);

    emit(
      CreateDao<OTW, CoinType> {
        dao_id: object::id(&dao),
        admin_id: object::id(&admin),
        creator: tx_context::sender(ctx),
        voting_delay,
        voting_period,
        voting_quorum_rate,
        min_action_delay,
        min_quorum_votes
      }
    );

    transfer::public_transfer(admin, object::uid_to_address(&dao.id));

    dao
  }

  // ** Important Make sure the voting_period and min_quorum_votes is adequate because a large holder can vote to withdraw all coins from the treasury.
  // ** Also major stakeholders should monitor all proposals to ensure they vote against malicious proposals.
  public fun new_with_treasury<OTW: drop, CoinType>(
    otw: OTW, 
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u64, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    allow_flashloan: bool,
    ctx: &mut TxContext
  ): (Dao<OTW>, DaoTreasury<OTW>) {
    let dao = new<OTW, CoinType>(otw, voting_delay, voting_period, voting_quorum_rate, min_action_delay, min_quorum_votes, ctx);
    let treasury = dao_treasury::create<OTW>(object::id(&dao), allow_flashloan, ctx);

    option::fill(&mut dao.treasury, object::id(&treasury));

    (dao, treasury)
  }

  //

  public fun proposer<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): address {
    proposal.proposer
  }

  public fun start_time<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.start_time
  } 

  public fun end_time<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.end_time
  }     

  public fun for_votes<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.for_votes
  }   

  public fun against_votes<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.against_votes
  }  

  public fun eta<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.eta
  }   

  public fun action_delay<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.action_delay
  }

  public fun quorum_votes<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.quorum_votes
  }           

  public fun voting_quorum_rate<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.voting_quorum_rate
  }

  public fun hash<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): vector<u8> {
    proposal.hash
  }    

  public fun authorized_witness<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): TypeName {
    proposal.authorized_witness
  }  

  public fun capability_id<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): Option<ID> {
    proposal.capability_id
  }    

  public fun coin_type<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): TypeName {
    proposal.coin_type
  }   

  public fun balance<DaoWitness: drop, CoinType>(vote: &Vote<DaoWitness,  CoinType>): u64 {
    balance::value(&vote.balance)
  } 

  public fun proposal_id<DaoWitness: drop, CoinType>(vote: &Vote<DaoWitness,  CoinType>): ID {
    vote.proposal_id
  }   

  public fun vote_end_time<DaoWitness: drop, CoinType>(vote: &Vote<DaoWitness,  CoinType>): u64 {
    vote.end_time
  } 

  public fun agree<DaoWitness: drop, CoinType>(vote: &Vote<DaoWitness,  CoinType>): bool {
    vote.agree
  } 

  //

  public fun propose<DaoWitness: drop>(
    dao: &mut Dao<DaoWitness>,
    c: &Clock,
    authorized_witness: TypeName,
    capability_id: Option<ID>,
    action_delay: u64,
    quorum_votes: u64,
    hash: vector<u8>,// hash proposal title/content
    ctx: &mut TxContext    
  ): Proposal<DaoWitness> {
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
      authorized_witness,
      capability_id,
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

  public fun execute_proposal<DaoWitness: drop, AuhorizedWitness: drop, Capability: key + store>(
    dao: &mut Dao<DaoWitness>,
    proposal: &mut Proposal<DaoWitness>, 
    _: AuhorizedWitness,
    receive_ticket: Receiving<Capability>,
    c: &Clock
  ): (Capability, CapabilityReceipt) {
    let now = clock::timestamp_ms(c);
    assert!(get_proposal_state(proposal, now) == EXECUTABLE, ECannotExecuteThisProposal);
    assert!(now >= proposal.end_time + proposal.action_delay, ETooEarlyToExecute);
    assert!(type_name::get<AuhorizedWitness>() == proposal.authorized_witness, EInvalidExecuteWitness);

    let proposal_capability_id = option::extract(&mut proposal.capability_id);

    // assert!(transfer::receiving_object_id(&receive_ticket) == proposal_capability_id, EInvalidExecuteCapability);

    let capability = transfer::public_receive(&mut dao.id, receive_ticket);

    let receipt = CapabilityReceipt {
      capability_id: proposal_capability_id,
      dao_id: object::id(dao)
    };

    (capability, receipt)
  }

  public fun return_capability<DaoWitness: drop, Capability: key + store>(dao: &Dao<DaoWitness>, cap: Capability, receipt: CapabilityReceipt) {
    let CapabilityReceipt { dao_id, capability_id } = receipt;

    assert!(dao_id == object::id(dao), EInvalidReturnDAO);
    assert!(capability_id == object::id(&cap), EInvalidReturnCapability);

    transfer::public_transfer(cap, object::uid_to_address(&dao.id));
  }

  public fun proposal_state<DaoWitness: drop>(proposal: &Proposal<DaoWitness>, c: &Clock): u8 {
    get_proposal_state(proposal, clock::timestamp_ms(c))
  }

  public fun view_vote<DaoWitness: drop, CoinType>(
    vote: &Vote<DaoWitness, CoinType>
  ): (ID, ID, u64, bool, u64) {
    (object::id(vote), vote.proposal_id, balance::value(&vote.balance), vote.agree, vote.end_time)
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
    } else if (option::is_some(&proposal.capability_id)) {
      EXECUTABLE
    } else {
      EXTRACTED
    }
  }
  
   // Only Proposal can update Dao settings

  public fun update_dao_config<DaoWitness: drop>(
    dao: &mut Dao<DaoWitness>,
    _: &DaoAdmin<DaoWitness>,
    voting_delay: Option<u64>, 
    voting_period: Option<u64>, 
    voting_quorum_rate: Option<u64>, 
    min_action_delay: Option<u64>, 
    min_quorum_votes: Option<u64>
  ) {

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