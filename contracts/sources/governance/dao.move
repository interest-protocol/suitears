// Based from https://github.com/starcoinorg/starcoin-framework/blob/main/sources/Dao.move
module suitears::dao {
  use std::option::{Self, Option};

  use sui::event::emit;
  use sui::clock::{Self, Clock};
  use sui::object::{Self, ID, UID};
  use sui::types::is_one_time_witness;
  use sui::tx_context::{Self, TxContext};

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

  struct DAO<phantom OTW, phantom CoinType> has key {
    id: UID,
    next_proposal_id: u256,
    /// after proposal created, how long use should wait before he can vote (in milliseconds)
    voting_delay: u64,
    /// how long the voting window is (in milliseconds).
    voting_period: u64,
    /// the quorum rate to agree on the proposal.
    /// if 50% votes needed, then the voting_quorum_rate should be 50.
    /// it should between (0, 100].
    voting_quorum_rate: u8,
    /// how long the proposal should wait before it can be executed (in milliseconds).
    min_action_delay: u64,
    min_quorum_votes: u64
  }

  struct Proposal<phantom DAOWitness: drop, phantom ModuleWitness: drop, phantom CoinType, T: store> has key, store {
    id: UID,
    proposer: address,
    start_time: u64,
    end_time: u64,
    for_votes: u64,
    agaisnt_votes: u64,
    eta: u64,
    action_delay: u64,
    quorum_votes: u64,
    min_quorum_votes: u64,
    payload: Option<T>
  }

  // Events

  struct CreateDAO<phantom OTW, phantom CoinType> has copy, drop {
    dao_id: ID,
    creator: address,
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u8, 
    min_action_delay: u64, 
    min_quorum_votes: u64
  }

  struct NewProposal<phantom DAOWitness, phantom ModuleWitness, phantom CoinType, phantom T> has copy, drop {
    proposal_id: ID,
    proposer: address,
  }

  public fun create<OTW: drop, CoinType>(
    otw: OTW, 
    voting_delay: u64, 
    voting_period: u64, 
    voting_quorum_rate: u8, 
    min_action_delay: u64, 
    min_quorum_votes: u64,
    ctx: &mut TxContext
  ): DAO<OTW, CoinType> {
    assert!(is_one_time_witness(&otw), EInvalidOTW);
    assert!(100 >= voting_quorum_rate && voting_quorum_rate != 0, EInvalidQuorumRate);
    assert!(voting_delay != 0, EInvalidVotingDelay);
    assert!(voting_period != 0, EInvalidVotingPeriod);
    assert!(min_action_delay != 0, EInvalidMinActionDelay);
    assert!(min_quorum_votes != 0, EInvalidMinQuorumVotes);

    let dao = DAO {
      id: object::new(ctx),
      next_proposal_id: 0,
      voting_delay,
      voting_period,
      voting_quorum_rate,
      min_action_delay,
      min_quorum_votes
    };

    emit(
      CreateDAO<OTW, CoinType> {
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

  public fun propose<DAOWitness: drop, ModuleWitness: drop, CoinType, T: store>(
    dao: &mut DAO<DAOWitness, CoinType>,
    c: &Clock,
    payload: Option<T>,
    action_delay: u64,
    min_quorum_votes: u64,
    ctx: &mut TxContext
  ): Proposal<DAOWitness, ModuleWitness,  CoinType, T> {
    assert!(action_delay >= dao.min_action_delay, EActionDelayTooSmall);
    assert!(min_quorum_votes >= dao.min_quorum_votes, EMinQuorumVotesTooSmall);

    let start_time = clock::timestamp_ms(c) + dao.voting_delay;

    let proposal = Proposal {
      id: object::new(ctx),
      proposer: tx_context::sender(ctx),
      start_time,
      end_time: start_time + dao.voting_period,
      for_votes: 0,
      agaisnt_votes: 0,
      eta: 04,
      action_delay,
      quorum_votes: 0,
      min_quorum_votes:dao.min_quorum_votes,
      payload
    };

    emit(NewProposal<DAOWitness, ModuleWitness,  CoinType, T> { proposal_id: object::id(&proposal), proposer: proposal.proposer });

    proposal
  }



  public fun pending(): u8 {
    PENDING
  }

  public fun active(): u8 {
    ACTIVE
  }

  public fun defeated(): u8 {
    DEFEATED
  }

  public fun agreed(): u8 {
    AGREED
  }

  public fun queued(): u8 {
    QUEUED  
  }

  public fun executable(): u8 {
    EXECUTABLE
  }

  public fun extracted(): u8 {
    EXTRACTED
  }



}