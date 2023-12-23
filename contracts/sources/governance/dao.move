// TODO - Mysten Labs is working so we can test Receiving Object in move modules. We need to test it once it is live.  
/*
*
* @title Decentralized Autonomous Organization
*
* @notice It allows anyone to create a DAO, submit proposals, and execute actions on-chain.  
* Proposals are voted by depositing coins. 1 Coin is 1 Vote.  
* Daos only supports 1 Coin type. 
*
* @dev The idea is to send capabilities to the DAO via `sui::transfer::transfer`.  
* Users can borrow the capabilities via successful proposals.    
* Developers must write custom modules that pass the `AuthorizedWitness` to borrow the capability when executing proposals. 
* {Dao} relies on open-source code to make sure the Modules that are executing proposals do what they agreed to do. 
*   
* @dev Proposal Life Cycle   
*
*                                                         Finished
*                                             Success -> 
*                                                         Action Delay -> Execution -> Finished 
* Create -> Voting Delay -> Voting Period ->             
*                                             Failed -> Finished
* 
*
* @dev A Successful {Proposal} requires: 
* - for_votes > agaisnt_votes  
* - for_votes / total_votes > quorum rate  
* - for_votes >= min_quorum_votes
*
* @dev {Vote} Life Cycle 
*
*                                 -> Wait for Proposal to Finish -> Unstake 
* Deposit Coin -> Vote (yes/no) ->
*                                 -> Revoke
*
* @dev Each {Vote} struct belongs to a specific {Proposal} via the `vote.proposal_id` field.
*  
* A voter can revoke his vote and recover his `sui::coin::Coin` if the {Proposal} is active.  
* A voter can recover his coins once the voting period ends.  
* A {Vote} created from {ProposalA} cannot be used in {ProposalB}.  
*
* @dev It was inspired by https://github.com/starcoinorg/starcoin-framework/blob/main/sources/Dao.move.  
*/
module suitears::dao {
  // === Imports ===

  use std::option::{Self, Option};
  use std::type_name::{Self, TypeName};
  use std::string::{Self, String};

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

  // @dev The proposal has been executed.  
  const FINISHED: u8 = 7;

  // === Errors ===

  // @dev When a DAO is created without a One Time Witness.  
  // {Dao<OTW>} must be created in a fun init to make sure they are unique.   
  const EInvalidOTW: u64 = 0;

  // @dev The rate has to be between 0 < rate < 1_000_000_000. 
  // 1_000_000_000 represents 100%.  
  // It is thrown when a DAO is created with a rate out of bounds.  
  const EInvalidQuorumRate: u64 = 1;

  // @dev Thrown when a {Proposal} is created with a time delay lower than the {Dao}'s minimum voting delay. 
  const EActionDelayTooShort: u64 = 2;

  // @dev Thrown when a {Proposal} is created with a votes quorum lower than the {Dao}'s minimum votes quorum.  
  const EMinQuorumVotesTooSmall: u64 = 3;

  // @dev Thrown when someone tries to vote on a {Proposal} that is pending. 
  const EProposalMustBeActive: u64 = 4; 

  // @dev Thrown when someone tries to vote with a zero value `sui::coin::Coin`.  
  const ECannotVoteWithZeroCoinValue: u64 = 5; 

  // @dev When a user tries to destroy their {Vote} before the {Proposal} ends.  
  // User has to revoke his vote if he wishes to get his `sui::coin::Coin` back before the end of the {Proposal}.   
  const ECannotUnstakeFromAnActiveProposal: u64 = 6;

  // @dev A user cannot use a {Proposal} {Vote} on another {Proposal}.  
  const EVoteAndProposalIdMismatch: u64 = 7; 

  // @dev When a user tries to execute a proposal that cannot be executable.   
  const ECannotExecuteThisProposal: u64 = 8;

  // @dev Thrown if a {Proposal} is executed before the the time delay.  
  const ETooEarlyToExecute: u64 = 9;

  // @dev Thrown if a {Proposal} is created without a hash. 
  // @dev Hash is supposed to be the hash of the description of the proposal.  
  const EEmptyHash: u64 = 10;

  // @dev Thrown when someone tries to queue a {Proposal} that has been defeated.  
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
    // The minimum quorum rate to pass a proposal.
    // If 50% votes are needed, then the voting_quorum_rate should be 500_000_000.
    // It should be between (0, 1e9].
    voting_quorum_rate: u64,
    // How long the proposal should wait before it can be executed (in milliseconds).
    min_action_delay: u64, 
    // Minimum amount of votes for a {Proposal} to be successful even if it is higher than the against votes and the quorum rate.  
    min_quorum_votes: u64,
    // The `sui::object::ID` of the Treasury.  
    treasury: ID,
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
    // Time Delay between a successful  {Proposal} `end_time` and when it is allowed to be executed. 
    // It allows users who disagree with the proposal to make changes. 
    action_delay: u64, 
    // The minimum amount of `for_votes` for a {Proposal} to pass. 
    quorum_votes: u64, 
    // The minimum support rate for a {Proposal} to pass. 
    voting_quorum_rate: u64, 
    // The hash of the description of this proposal 
    hash: String,
    // The Witness that is allowed to call {execute}. 
    // Not executable proposals do not have an authorized_witness
    authorized_witness: Option<TypeName>,
    // The `sui::object::ID` that this proposal needs to execute. 
    // Not all proposals are executable.  
    capability_id: Option<ID>,
    // The CoinType of the {Dao}
    coin_type: TypeName
  }

 // @dev A Hot Potato to ensure that the borrowed Capability is returned to the {Dao}. 
  struct CapabilityRequest {
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
    // If it is a for or against vote. 
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
  * @notice Creates a new {DAO<OTW>} with a {DaoTreasury<OTW>}.  
  *
  * @dev {Dao} can only be created in an init function.  
  * @dev Make sure that the voting_period and min_quorum_votes are adequate because a large holder can vote to withdraw all coins from the treasury.
  * @dev Stakeholders should monitor all proposals to ensure they vote against malicious proposals.
  *
  * @param otw A One Time Witness to ensure that the {Dao<OTW>} is unique.  
  * @param voting_delay The minimum waiting period between the creation of a proposal and the voting period.  
  * @param voting_period The duration of the voting period.  
  * @param voting_quorum_rate The minimum percentage of votes to pass a proposal. E.g. for_votes / total_votes. keep in mind (0, 1_000_000_000]  
  * @param min_action_delay The minimum delay required to execute a proposal after it passes.  
  * @param min_quorum_votes The minimum votes required for a {Proposal} to be successful.   
  * @return Dao<OTW>  
  * @return Treasury<OTW>
  *
  * aborts-if:   
  * - `otw` is not a One Time Witness.   
  * - `voting_quorum_rate` is larger than 1_000_000_000 
  * - `voting_quorum_rate` is zero.  
  */   
  public fun new<OTW: drop, CoinType: drop>(
    otw: OTW, 
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u64, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    ctx: &mut TxContext
  ): (Dao<OTW>, DaoTreasury<OTW>) {
    assert!(is_one_time_witness(&otw), EInvalidOTW);

    new_impl<OTW, CoinType>(
      voting_delay, 
      voting_period, 
      voting_quorum_rate, 
      min_action_delay, 
      min_quorum_votes, 
      ctx
    )
  }

  // === Public Dao View Functions ===  

  /*
  * @notice Returns the minimum voting delay of the Dao. 
  *
  * @param self a {Dao<OTW>}
  * @return u64
  */
  public fun voting_delay<DaoWitness>(self: &Dao<DaoWitness>): u64 {
    self.voting_delay
  }

  /*
  * @notice Returns the minimum voting period of the Dao. 
  *
  * @param self a {Dao<OTW>}
  * @return u64
  */
  public fun voting_period<DaoWitness>(self: &Dao<DaoWitness>): u64 {
    self.voting_period
  }  

  /*
  * @notice Returns the minimum voting quorum rate of the Dao. 
  *
  * @param self a {Dao<OTW>}
  * @return u64
  */
  public fun dao_voting_quorum_rate<DaoWitness>(self: &Dao<DaoWitness>): u64 {
    self.voting_quorum_rate
  }    

  /*
  * @notice Returns the minimum action delay of the Dao. 
  *
  * @param self a {Dao<OTW>}
  * @return u64
  */
  public fun min_action_delay<DaoWitness>(self: &Dao<DaoWitness>): u64 {
    self.min_action_delay
  }    

  /*
  * @notice Returns the minimum quorum votes of the Dao. 
  *
  * @param self a {Dao<OTW>}
  * @return u64
  */
  public fun min_quorum_votes<DaoWitness>(self: &Dao<DaoWitness>): u64 {
    self.min_quorum_votes
  }   

  /*
  * @notice Returns the `sui::object::id` of the Dao wrapped in an `std::option`.  
  *
  * @param self a {Dao<OTW>}
  * @return ID
  */
  public fun treasury<DaoWitness>(self: &Dao<DaoWitness>): ID {
    self.treasury
  }    

  /*
  * @notice Returns the `std::type_name` of the Dao's coin type. This is the Coin<Type> that can be used to vote on proposals. 
  *
  * @param self a {Dao<OTW>}
  * @return TypeName
  */
  public fun dao_coin_type<DaoWitness>(self: &Dao<DaoWitness>): TypeName {
    self.coin_type
  }

  /*
  * @notice Returns the `sui::object::ID` of Dao's admin capability. 
  *
  * @param self a {Dao<OTW>}
  * @return ID
  */
  public fun admin<DaoWitness>(self: &Dao<DaoWitness>): ID {
    self.admin_id
  } 

  // === Public Proposal View Functions ===        

  /*
  * @notice Returns the address of the user who created the 'proposal'. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return address
  */
  public fun proposer<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): address {
    proposal.proposer
  }

  /*
  * @notice Returns start timestamp of the `proposal`. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return u64
  */
  public fun start_time<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.start_time
  } 

  /*
  * @notice Returns end timestamp of the `proposal`. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return u64
  */
  public fun end_time<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.end_time
  }     

  /*
  * @notice Returns the number of votes that support this `proposal`. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return u64
  */
  public fun for_votes<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.for_votes
  }   

  /*
  * @notice Returns the number of votes against this `proposal`. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return u64
  */
  public fun against_votes<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.against_votes
  }  

  /*
  * @notice Returns an estimation of when a proposal is successful and can be executed. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return u64
  */
  public fun eta<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.eta
  }   

  /*
  * @notice Returns the minimum time a successful `proposal` has to wait before it can be executed. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return u64
  */
  public fun action_delay<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.action_delay
  }

  /*
  * @notice Returns the minimum number of votes required for a successful `proposal`. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return u64
  */
  public fun quorum_votes<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.quorum_votes
  }           

  /*
  * @notice Returns the minimum rate for a `proposal` to pass. Formula:  for_votes / total_votes. 
  *
  * @dev 100% is represented by 1_000_000_000. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return u64
  */
  public fun voting_quorum_rate<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): u64 {
    proposal.voting_quorum_rate
  }

  /*
  * @notice Returns the hash of the description of the `proposal`. 
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return vector<u8>
  */
  public fun hash<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): String {
    proposal.hash
  }    

  /*
  * @notice Returns the `std::type_name::TypeName` of the Witness that can execute the `proposal`.   
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return TypeName
  */
  public fun authorized_witness<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): Option<TypeName> {
    proposal.authorized_witness
  }  

  /*
  * @notice Returns the `sui::object::ID` of the Capability that the `proposal` requires to execute.   
  *
  * @dev A proposal without a `capability_id` is not executable on chain.  
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return Option<ID>
  */
  public fun capability_id<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): Option<ID> {
    proposal.capability_id
  }    

  /*
  * @notice Returns the CoinType of the `proposal. Votes must use this CoinType.     
  *
  * @param proposal The {Proposal<DaoWitness>}
  * @return TypeName
  */
  public fun coin_type<DaoWitness: drop>(proposal: &Proposal<DaoWitness>): TypeName {
    proposal.coin_type
  }   

  // === Public Vote View Functions ===     

  /*
  * @notice Returns the number of votes.  
  *
  * @dev The coin amount is the number of votes.     
  *
  * @param vote The {Vote<DaoWitness,  CoinType>}
  * @return u64
  */
  public fun balance<DaoWitness: drop, CoinType>(vote: &Vote<DaoWitness,  CoinType>): u64 {
    balance::value(&vote.balance)
  } 

  /*
  * @notice Returns the {Proposal} `sui::object::ID`.     
  *
  * @param vote The {Vote<DaoWitness,  CoinType>}
  * @return ID
  */
  public fun proposal_id<DaoWitness: drop, CoinType>(vote: &Vote<DaoWitness,  CoinType>): ID {
    vote.proposal_id
  }   

  /*
  * @notice Returns the ending timestamp of the proposal. Users can withdraw their deposited coins afterward.   
  *
  * @param vote The {Vote<DaoWitness,  CoinType>}
  * @return u64
  */
  public fun vote_end_time<DaoWitness: drop, CoinType>(vote: &Vote<DaoWitness,  CoinType>): u64 {
    vote.end_time
  } 

  /*
  * @notice Returns if it is a for or against vote.    
  *
  * @param vote The {Vote<DaoWitness,  CoinType>}
  * @return bool
  */
  public fun agree<DaoWitness: drop, CoinType>(vote: &Vote<DaoWitness,  CoinType>): bool {
    vote.agree
  } 

  /*
  * @notice Returns the `proposal` state.  
  * 
  * @param proposal A {Proposal}.  
  * @return u8. It represents a Proposal State. 
  */
  public fun state<DaoWitness: drop>(proposal: &Proposal<DaoWitness>, c: &Clock): u8 {
    proposal_state_impl(proposal, clock::timestamp_ms(c))
  }  

  // === Public Mutative Functions ===     

  /*
  * @notice Creates a {Proposal} 
  *
  * @param dao The {Dao<OTW>} 
  * @param c The shared `sui::clock::Clock` object.  
  * @param authorized_witness The Witness required to execute this proposal.  
  * @param capability_id The `sui::object::ID` of the Capability that this proposal needs to be executed. If a proposal is not executable pass `option::none()`,
  * @param action_delay The minimum waiting period for a successful {Proposal} to be executed.  
  * @param quorum_votes The minimum votes required for a {Proposal} to be successful.   
  * @param hash The hash of the proposal's description.  
  * @return Proposal<DaoWitness> 
  *
  * aborts-if:   
  * - `action_delay` < `dao.min_action_delay`.  
  * - `quorum_votes` < `dao.min_quorum_votes`.  
  * - `hash` is empty.
  */
  public fun propose<DaoWitness: drop>(
    dao: &mut Dao<DaoWitness>,
    c: &Clock,
    authorized_witness: Option<TypeName>,
    capability_id: Option<ID>,
    action_delay: u64,
    quorum_votes: u64,
    hash: String,// hash proposal title/content
    ctx: &mut TxContext    
  ): Proposal<DaoWitness> {
    assert!(action_delay >= dao.min_action_delay, EActionDelayTooShort);
    assert!(quorum_votes >= dao.min_quorum_votes, EMinQuorumVotesTooSmall);
    assert!(string::length(&hash) != 0, EEmptyHash);

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

 /*
 * @notice Allows a user to use coins to vote for a `proposal`, either against or for depending on `agree`.  
 *
 * @param proposal The proposal the user is voting for. 
 * @param c The `sui::clock::Clock`
 * @param stake The coin that the user will deposit to vote.  
 * @param agree Determines if the vote is for or against.  
 * @return Vote<DaoWitness, CoinType>  
 *
 * aborts-if:  
 * - if the proposal is not `ACTIVE` 
 * - if the `stake` type does not match the `proposal.coin_type`
 * - if a user tries to vote with a zero coin `stake`.  
 */
  public fun cast_vote<DaoWitness: drop, CoinType>(
    proposal: &mut Proposal<DaoWitness>,
    c: &Clock,
    stake: Coin<CoinType>,
    agree: bool,
    ctx: &mut TxContext
  ): Vote<DaoWitness, CoinType> {
    assert!(proposal_state_impl(proposal, clock::timestamp_ms(c)) == ACTIVE, EProposalMustBeActive);
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

 /*
 * @notice Allows a user to change his vote for a `proposal`.  
 *
 * @param proposal The proposal the user is voting for. 
 * @param vote The vote that will be changed.  
 * @param c The `sui::clock::Clock` 
 *
 * aborts-if:  
 * - if the proposal is not `ACTIVE`.  
 * - if the `vote` does not belong to the `proposal`.  
 */
  public fun change_vote<DaoWitness: drop, CoinType>(
    proposal: &mut Proposal<DaoWitness>,
    vote: &mut Vote<DaoWitness,  CoinType>,
    c: &Clock,
    ctx: &mut TxContext
  ) {
    assert!(proposal_state_impl(proposal, clock::timestamp_ms(c)) == ACTIVE, EProposalMustBeActive);
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

  /*
  * @notice Allows a user to revoke his vote for a `proposal` and get his coin back.  
  *
  * @dev It will deduct the user votes from the `proposal`.  
  *
  * @param proposal The proposal the user is voting for. 
  * @param vote The vote that will be destroyed.     
  * @param c The `sui::clock::Clock`
  * @return Coin<CoinType> 
  *
  * aborts-if:  
  * - if the proposal is not `ACTIVE` 
  * - if the `vote` does not belong to the `proposal`.   
  */
  public fun revoke_vote<DaoWitness: drop, CoinType>(
    proposal: &mut Proposal<DaoWitness>,
    vote: Vote<DaoWitness, CoinType>,
    c: &Clock,
    ctx: &mut TxContext    
  ): Coin<CoinType> {
    assert!(proposal_state_impl(proposal, clock::timestamp_ms(c)) == ACTIVE, EProposalMustBeActive);
    let proposal_id = object::id(proposal);
    assert!(proposal_id == vote.proposal_id, EVoteAndProposalIdMismatch);

    let value = balance::value(&vote.balance);
    if (vote.agree) proposal.for_votes = proposal.for_votes - value else proposal.against_votes = proposal.against_votes - value;

    emit(RevokeVote<DaoWitness,  CoinType>{ proposal_id: proposal_id, value, agree: vote.agree, voter: tx_context::sender(ctx) });

    destroy_vote(vote, ctx)
  }

  /*
  * @notice Allows a user to unstake his vote to get his coins back after the `proposal` has ended.  
  *
  * @param proposal The proposal the user is voting for. 
  * @param vote The vote that will be destroyed.     
  * @param c The `sui::clock::Clock`
  * @return Coin<CoinType>
  *
  * aborts-if:  
  * - if the proposal has not ended. 
  * - if the `vote.proposal_id` type does not match the `proposal.id` 
  */
  public fun unstake_vote<DaoWitness: drop, CoinType>(
    proposal: &Proposal<DaoWitness>,
    vote: Vote<DaoWitness, CoinType>,
    c: &Clock,
    ctx: &mut TxContext      
  ): Coin<CoinType> {
    // Everything greater than active can be unstaked 
    assert!(proposal_state_impl(proposal, clock::timestamp_ms(c)) > ACTIVE, ECannotUnstakeFromAnActiveProposal);
    let proposal_id = object::id(proposal);
    assert!(proposal_id == vote.proposal_id, EVoteAndProposalIdMismatch);

    emit(UnstakeVote<DaoWitness, CoinType>{ proposal_id: proposal_id, value: balance::value(&vote.balance), agree: vote.agree, voter: tx_context::sender(ctx) });

    destroy_vote(vote, ctx)
  }

  /*
  * @notice Allows a successful `proposal` to be queued.  
  *
  * @param proposal The proposal the user is voting for.   
  * @param c The `sui::clock::Clock`
  *
  * aborts-if:  
  * - if the `proposal` state is not AGREED. 
  */
  public fun queue<DaoWitness: drop>(
    proposal: &mut Proposal<DaoWitness>, 
    c: &Clock
  ) {
    // Only agreed proposal can be submitted.
    let now = clock::timestamp_ms(c);
    assert!(proposal_state_impl(proposal, now) == AGREED, EProposalNotPassed);
    proposal.eta = now + proposal.action_delay;
  }

  /*
  * @notice Executes a `proposal`.  
  *
  * @param dao The {Dao<OTW>}   
  * @param proposal The proposal that will be executed.
  * @param _ The witness that is authorized to borrow the Capability.   
  * @param receive_ticket A receipt struct to borrow the Capability.     
  * @param c The `sui::clock::Clock`
  * @return Capability required to execute the proposal 
  * @return CapabilityRequest A hot potato to ensure that the borrower returns the Capability to the `dao`. 
  *
  * aborts-if:  
  * - if the `proposal` state is not EXECUTABLE 
  * - if there has not passed enough time since the `end_time` 
  * - if the Authorized Witness does not match the `proposal.authorized_witness`.  
  * - if the borrowed capability does not match the `proposal.capability_id`.  
  */
  public fun execute<DaoWitness: drop, AuhorizedWitness: drop, Capability: key + store>(
    dao: &mut Dao<DaoWitness>,
    proposal: &mut Proposal<DaoWitness>, 
    _: AuhorizedWitness,
    receive_ticket: Receiving<Capability>,
    c: &Clock
  ): (Capability, CapabilityRequest) {
    let now = clock::timestamp_ms(c);
    assert!(proposal_state_impl(proposal, now) == EXECUTABLE, ECannotExecuteThisProposal);
    assert!(now >= proposal.end_time + proposal.action_delay, ETooEarlyToExecute);
    assert!(type_name::get<AuhorizedWitness>() == option::extract(&mut proposal.authorized_witness), EInvalidExecuteWitness);

    let proposal_capability_id = option::extract(&mut proposal.capability_id);

    let capability = transfer::public_receive(&mut dao.id, receive_ticket);

    assert!(object::id(&capability) == proposal_capability_id, EInvalidExecuteCapability);

    let receipt = CapabilityRequest {
      capability_id: proposal_capability_id,
      dao_id: object::id(dao)
    };

    (capability, receipt)
  }

  /*
  * @notice Returns the borrowed `cap` to the `dao`.  
  *
  * @param dao The {Dao<OTW>}   
  * @param cap The capability that will be returned to the `dao`. 
  * @param receipt The request hot potato.  
  */
  public fun return_capability<DaoWitness: drop, Capability: key + store>(dao: &Dao<DaoWitness>, cap: Capability, receipt: CapabilityRequest) {
    let CapabilityRequest { dao_id, capability_id } = receipt;

    assert!(dao_id == object::id(dao), EInvalidReturnDAO);
    assert!(capability_id == object::id(&cap), EInvalidReturnCapability);

    transfer::public_transfer(cap, object::uid_to_address(&dao.id));
  } 

  /*
  * @notice updates the configuration settings of the `dao`. 
  *
  * @dev Can only be called by a proposal. 
  * @dev If the value of the argument is `option::none()`, the value will not be updated. 
  * 
  * @param dao The {Dao<OTW>}   
  * @param _ Immutable reference to the {DaoAdmin}.  
  * @param voting_delay The minimum waiting period between the creation of a proposal and the voting period.  
  * @param voting_period The duration of the voting period.  
  * @param voting_quorum_rate The minimum percentage of votes. E.g. for_votes / total_votes. Range = (0, 1_000_000_000]  
  * @param min_action_delay The delay required to execute a proposal after it passes.    
  * @param min_quorum_votes The minimum votes required for a {Proposal} to be successful.    
  *
  * aborts-if:  
  * - if the `dao.voting_quorum_rate` is larger than 1e9.
  * - if the `dao.voting_quorum_rate` is zero. 
  */
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

    assert!(1_000_000_000 >= dao.voting_quorum_rate && dao.voting_quorum_rate != 0, EInvalidQuorumRate);

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

  // === Private Functions ===   

  /*
  * @dev The implementation of the {new} function.
  */   
  fun new_impl<OTW: drop, CoinType>( 
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u64, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    ctx: &mut TxContext
  ): (Dao<OTW>, DaoTreasury<OTW>) {
    assert!(1_000_000_000 >= voting_quorum_rate && voting_quorum_rate != 0, EInvalidQuorumRate);
    
    let admin = dao_admin::new<OTW>(ctx);
    let admin_id = object::id(&admin);

    let dao_id = object::new(ctx);

    let treasury = dao_treasury::new<OTW>(*object::uid_as_inner(&dao_id), ctx);

    let dao = Dao<OTW> {
      id: dao_id,
      voting_delay,
      voting_period,
      voting_quorum_rate,
      min_action_delay,
      min_quorum_votes,
      treasury: object::id(&treasury),
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

    (dao, treasury)
  }   

  /*
  * @notice Destroys the `vote` and returns the coin deposited.  
  * 
  * @param vote the vote that will be destroyed.  
  * @return Coin<CoinType>.  
  */
  fun destroy_vote<DaoWitness: drop, CoinType>(vote: Vote<DaoWitness, CoinType>, ctx: &mut TxContext): Coin<CoinType> {
    let Vote {id, balance, agree: _, end_time: _, proposal_id: _} = vote;
    object::delete(id);

    coin::from_balance(balance, ctx)
  }

  /*
  * @notice Returns the state of the `proposal`.  
  * 
  * @param proposal The proposal that will be executed.
  * @param current_time The current time in Sui Network is in milliseconds.    
  */
  fun proposal_state_impl<DaoWitness: drop>(
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
      proposal.for_votes + proposal.against_votes == 0 ||
      proposal.for_votes <= proposal.against_votes ||
      proposal.for_votes + proposal.against_votes < proposal.quorum_votes || 
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
      FINISHED
    }
  }

  // === Test Only Functions ===

  #[test_only]
  public fun new_for_testing<OTW: drop, CoinType>(
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u64, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    ctx: &mut TxContext    
  ): (Dao<OTW>, DaoTreasury<OTW>) {
    new_impl<OTW, CoinType>(
      voting_delay,
      voting_period,
      voting_quorum_rate,
      min_action_delay,
      min_quorum_votes,
      ctx
    )
  }   
}