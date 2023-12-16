/*
* @title Decentralized Autonomous Organization
*
* @notice It allows anyone to create a DAO, submit proposals and execute actions on-chain.  
* Proposals are voted by deposting coins. 1 Coin is 1 Vote.  
* Daos only supports 1 Coin type. 
*
* @dev The idea is to send capabilities to the DAO via `sui::transfer::transfer`.  
* Users can borrow the capabilities via successful proposals.    
* Developers must write custom modules that pass the `AuthorizedWitness` to borrow the capability when executing proposals. 
* {Dao} relies on open source code to make sure the Modules that are executing proposals do what they agreed to do.    
*
* @dev Proposal Life Cycle
* Create -> Voting Delay -> Voting Period -> 
*
* Failure Route -> Ending
* Success Route -> Executing Delay -> Execution -> Ending 
*
* @dev A Success {Proposal} requires: 
* - for_votes > agaisnt_votes  
* - for_votes / total_votes > quorum rate  
* - for_votes >= min_quorum_votes
*
* @dev {Vote} Life Cycie 
* Deposit Coin -> Vote -> Wait for Proposal to Finish -> Withdraw
*
* @dev The {Vote} struct belongs to a specific {Proposal}.  
* A voter can only recover his `sui::coin::Coin` once the {Proposal} ends.  
* A {Vote} created from {ProposalA} cannot be used in {ProposalB}.  
*
* @dev It was inspired by https://github.com/starcoinorg/starcoin-framework/blob/main/sources/Dao.move.  
*/
module suitears::dao {
  // === Imports ===

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

  // === Constants ===

  // @dev Proposal has not started yet. 
  const PENDING: u8 = 1;
  // @dev Proposal has started. Users can start voting.  
  const ACTIVE: u8 = 2;
  // @dev The proposal has ended and failed to pass.  
  const DEFEATED: u8 = 3;
  // @dev The proposal has ended and it was successful. It will now be queued.  
  const AGREED: u8 = 4;
  // @dev The proposal was successful and now it is in a queue to be executed if it is executable. 
  // @dev This gives time for people to adjust to the upcoming change.   
  const QUEUED: u8 = 5;
  // @dev This proposal is ready to be executed.  
  const EXECUTABLE: u8 = 6;
  // @dev The proposal is considered finalized.  
  const EXTRACTED: u8 = 7;

  // === Errors ===

  // @dev When a DAO is created without a One Time Witness.  
  // {Dao<OTW>} must be created in a fun init to make sure they are unique.   
  const EInvalidOTW: u64 = 0;
  // @dev The rate has to be between 0 < rate < 1_000_000_000. 
  // 1_000_000_000 represents 100%.  
  // It is thrown when a DAO is created with a rate out of bounds.  
  const EInvalidQuorumRate: u64 = 1;
  // @dev Thrown when a {Proposal} is created with a time delay lower than the {Dao}'s minimum voting delay. 
  const EActionDelayTooSmall: u64 = 2;
  // @dev Thrown when a {Proposal} is created with a votes quorum lower than the {Dao}'s minimum votes quorum.  
  const EMinQuorumVotesTooSmall: u64 = 3;
  // @dev Thrown when someone tries to vote on a {Proposal} that is pending. 
  const EProposalMustBeActive: u64 = 4; 
  // @dev Thrown when someone tries to vote with a zero value `sui::coin::Coin`.  
  const ECannotVoteWithZeroCoinValue: u64 = 5; 
  // @dev When a user tries to destroy their {Vote} before the {Proposal} ends.  
  // Once a user votes, he has to wait until the {Proposal} ends to get back his coins.  
  const ECannotUnstakeFromAnActiveProposal: u64 = 6;
  // @dev A user cannot use a {Proposal} {Vote} on another {Proposal}.  
  const EVoteAndProposalIdMismatch: u64 = 7; 
  // @dev When a user tries to execute a proposal that cannot be executable.   
  const ECannotExecuteThisProposal: u64 = 8;
  // @dev Thrown if a {Proposal} is executed before the the time delay.  
  const ETooEarlyToExecute: u64 = 9;
  // @dev Thrown if a {Proposal} is created without a hash. 
  // @dev Hash suppose to be the hash of the the description of the proposal.  
  const EEmptyHash: u64 = 10;
  // @dev Thrown when someone tries to queue {Proposal} that has been defeated.  
  const EProposalNotPassed: u64 = 11;  
  // @dev User tries to vote for a {Proposal} with the wrong coin.  
  const EInvalidCoinType: u64 = 12;
  // @dev An unauthorized Module tries to execute a {Proposal} by passing the wrong witness.  
  const EInvalidExecuteWitness: u64 = 13; 
  // @dev When a Module tries to borrow the wrong Capability when executing a {Proposal}.  
  const EInvalidExecuteCapability: u64 = 14;
  // @dev When a user tries to return the wrong Capability to the {DAO}.  
  const EInvalidReturnCapability: u64 = 15;
  // @dev When a user tries to return the right Capability to the wrong {DAO}.  
  const EInvalidReturnDAO: u64 = 16;

  // === Structs ===

  struct Dao<phantom OTW> has key, store {
    id: UID,
    // Voters must wait `voting_delay` in milliseconds to start voting on new proposals.
    voting_delay: u64,
    // The voting duration of a proposal.  
    voting_period: u64,
    /// the quorum rate to agree on the proposal.
    /// if 50% votes needed, then the voting_quorum_rate should be 50.
    /// it should between (0, 100 * 1e9].
    voting_quorum_rate: u64,
    /// how long the proposal should wait before it can be executed (in milliseconds).
    min_action_delay: u64, 
    // minimum amount of votes for a {Proposal} to be successful even if it higher than the agaisnt votes and the quorum rate.  
    min_quorum_votes: u64,
    // The `sui::object::ID` of the Treasury.  
    // Not all {Dao}s have treasuries. 
    treasury: Option<ID>,
    // The CoinType that can vote on this DAO's proposal.  
    coin_type: TypeName,
    // The {DaoAdmin}
    admin_id: ID
  }

  struct Proposal<phantom DaoWitness: drop> has key, store {
    id: UID,
    // The user who created the proposal
    proposer: address,
    // When the users can start voting
    start_time: u64,
    // Users can no longer vote after the `end_time`. 
    end_time: u64,
    // How many votes support the {Proposal}.  
    for_votes: u64,
    // How many votes disagree with the {Proposal}.  
    against_votes: u64,
    // It is calculated by adding `end_time` and `action_delay`. It assumes the {Proposal} will be executed as soon as possible.  
    // Estimated Time of Arrival.  
    eta: u64, 
    // Time Delay between a sucessful {Proposal} `end_time` and when it is allowed to be executed. 
    // It allows users who disagree with the proposal to make changes. 
    action_delay: u64, 
    // The minimum amount of `for_votes` for a {Proposal} to pass. 
    quorum_votes: u64, 
    // The minimum support rate for a {Proposal} to pass. 
    voting_quorum_rate: u64, 
    // The hash of the description of this proposal 
    hash: vector<u8>,
    // The Witness that is allowed to call {execute}
    authorized_witness: TypeName,
    // The `sui::object::ID` that this proposal needs to execute. 
    // Not all proposals are executable.  
    capability_id: Option<ID>,
    // The CoinType of the {Dao}
    coin_type: TypeName
  }

  // @dev A Hot Potato to ensure that the borrowed Capability is returned to the {Dao}. 
  struct CapabilityReceipt {
    // @dev The `sui::object::ID` of the borrowed Capability.   
    capability_id: ID,
    // @dev The {DAO} that owns said Capability.  
    dao_id: ID
  }

  struct Vote<phantom DaoWitness: drop, phantom CoinType> has  key, store {
    id: UID,
    // The amount of Coin the user has used to vote for the {Proposal}. 
    balance: Balance<CoinType>,
    // The `sui::object::ID` of the {Proposal}.  
    proposal_id: ID,
    // The end_time of the {Proposal}.  
    // User can redeem back his `balance` after this timestamp.  
    end_time: u64,
    // If it is a for or agaisnt vote. 
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

  // === Public Create Function ===  

  /*
  * @notice Creates a new {DAO<OTW>}.  
  *
  * @dev {Dao} can only be created in an init function.  
  *
  * @param otw A One Time Witness to ensure that the {Dao<OTW>} is unique.  
  * @param voting_delay The minimum waiting period between the creation of a proposal and the voting period.  
  * @param voting_period The duration of the voting period.  
  * @param voting_quorum_rate The minimum percentage of for votes. E.g. for_votes / total_votes. keep in mint (0, 1_000_000_000]  
  * @param min_quorum_votes The minimum votes required for a {Proposal} to be sucessful.   
  * @return Dao<OTW>  
  *
  * aborts-if:   
  * - `otw` is not a One Time Witness.   
  * - `voting_quorum_rate` is larger than 1_000_000_000 
  * - `voting_quorum_rate` is zero.  
  */
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
    assert!(1_000_000_000 >= voting_quorum_rate && voting_quorum_rate != 0, EInvalidQuorumRate);

    let admin = dao_admin::new<OTW>(ctx);
    let admin_id = object::id(&admin);

    let dao = Dao<OTW> {
      id: object::new(ctx),
      voting_delay,
      voting_period,
      voting_quorum_rate,
      min_action_delay,
      min_quorum_votes,
      treasury: option::none(),
      coin_type: type_name::get<CoinType>(),
      admin_id
    };

    emit(
      CreateDao<OTW, CoinType> {
        dao_id: object::id(&dao),
        admin_id,
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

  /*
  * @notice Creates a new {DAO<OTW>} with a {DaoTreasury<OTW>}.  
  *
  * @dev {Dao} can only be created in an init function.  
  * @dev Important Make sure the voting_period and min_quorum_votes is adequate because a large holder can vote to withdraw all coins from the treasury.
  * @dev Also major stakeholders should monitor all proposals to ensure they vote against malicious proposals.
  *
  * @param otw A One Time Witness to ensure that the {Dao<OTW>} is unique.  
  * @param voting_delay The minimum waiting period between the creation of a proposal and the voting period.  
  * @param voting_period The duration of the voting period.  
  * @param voting_quorum_rate The minimum percentage of for votes. E.g. for_votes / total_votes. keep in mint (0, 1_000_000_000]  
  * @param min_quorum_votes The minimum votes required for a {Proposal} to be sucessful.   
  * @param allow_flashloan If the {DaoTreasury<OTW>} should allow flash loans.  
  * @return Dao<OTW>  
  * @return Treasury<OTW>
  *
  * aborts-if:   
  * - `otw` is not a One Time Witness.   
  * - `voting_quorum_rate` is larger than 1_000_000_000 
  * - `voting_quorum_rate` is zero.  
  */  
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

  // === Public View Functions ===  

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

  public fun execute<DaoWitness: drop, AuhorizedWitness: drop, Capability: key + store>(
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

    let capability = transfer::public_receive(&mut dao.id, receive_ticket);

    assert!(object::id(&capability) == proposal_capability_id, EInvalidExecuteCapability);

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