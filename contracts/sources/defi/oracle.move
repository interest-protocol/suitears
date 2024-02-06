module suitears::oracle {
  // === Imports ===

  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::transfer;
  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID, ID};  
  use sui::tx_context::TxContext;

  use suitears::math256;
  use suitears::owner::{Self, OwnerCap};

  // === Errors ===

  const EOracleMustHaveFeeds: u64 = 0;
  const EMustHavePositiveTimeLimit: u64 = 1;
  const EMustHavePositiveDeviation: u64 = 2;
  const ERequestAndOracleIdMismatch: u64 = 3;
  const EWrongNumberOfReports: u64 = 4;
  const EInvalidReportFeed: u64 = 5;
  const EStalePriceReport: u64 = 6;
  const EPriceCannotBeZero: u64 = 7;
  const EPriceDeviationIsTooHigh: u64 =  8;

  // === Constants ===

  const WAD: u256 = 1_000_000_000_000_000_000; // 1e18  

  // === Structs ===

  struct Oracle<phantom Witness: drop> has key, store {
    id: UID,
    feeds: vector<TypeName>,
    time_limit: u64,
    deviation: u256
  }  

  struct Report has store, copy, drop {
    feed: TypeName,
    price: u256,
    timestamp: u64
  }

  struct Request {
    oracle: ID,
    reports: vector<Report>
  }

  struct Price {
    oracle: ID,
    price: u256,
    decimals: u8,
    timestamp: u64    
  }

  // === Public-Mutative Functions ===

  public fun new<Witness: drop>(
    cap: &mut OwnerCap<Witness>,
    wit: Witness, 
    feeds: vector<TypeName>, 
    time_limit: u64, 
    deviation: u256, 
    ctx: &mut TxContext
  ): Oracle<Witness> {
    assert!(vector::length(&feeds) != 0, EOracleMustHaveFeeds);
    assert!(time_limit != 0, EMustHavePositiveTimeLimit);
    assert!(deviation != 0, EMustHavePositiveDeviation);

    let oracle = Oracle {
      id: object::new(ctx),
      feeds,
      time_limit,
      deviation
    };

    owner::add(cap, wit, object::id(&oracle));

    oracle
  }

  #[lint_allow(share_owned, custom_state_change)]
  public fun share<Witness: drop>(self: Oracle<Witness>) {
    transfer::share_object(self);
  }

  public fun request<Witness: drop>(self: &Oracle<Witness>): Request {
    Request {
      oracle: object::id(self),
      reports: vector[],
    }
  }

  public fun report<Witness: drop>(request: &mut Request, _: Witness, timestamp: u64, price: u64, decimals: u8) {
    vector::push_back(&mut request.reports, Report { 
      feed: type_name::get<Witness>(),
      price: math256::mul_div_down((price as u256), WAD, math256::pow(10, (decimals as u256))),
      timestamp
     });
  }

  public fun destroy_request<Witness: drop>(self: &Oracle<Witness>, request: Request, c:&Clock): Price {
    let Request { oracle, reports } = request;  

    assert!(oracle == object::id(self), ERequestAndOracleIdMismatch);

    let num_of_feeds = vector::length(&self.feeds);
    let num_of_reports = vector::length(&reports);

    assert!(num_of_feeds == num_of_reports, EWrongNumberOfReports);

    let i = 0;
    let leader_price = 0;
    let leader_timestamp = 0;
    let current_time = clock::timestamp_ms(c);

    while (num_of_feeds > i) {
      let feed = *vector::borrow(&self.feeds, i);
      let report = *vector::borrow(&reports, i);   

      assert!(feed == report.feed, EInvalidReportFeed);
      assert!(report.timestamp + self.time_limit >= current_time, EStalePriceReport);
      assert!(report.price != 0, EPriceCannotBeZero);

      if (i == 0) {
        leader_price = report.price;
        leader_timestamp = report.timestamp;
      } else {
        let diff = math256::diff(leader_price, report.price);
        let deviation = math256::mul_div_up(diff, WAD, leader_price);
        assert!(self.deviation >= deviation, EPriceDeviationIsTooHigh);
      };

      i = i + 1;
    };

    Price {
      oracle,
      price: leader_price,
      decimals: 18,
      timestamp: leader_timestamp          
    }
  }

  public fun destroy_price(price: Price): (ID, u256, u8, u64) {
    let Price { oracle, price,decimals, timestamp } = price;
    (oracle, price, decimals, timestamp)
  }

  // === Public-View Functions ===

  public fun feeds<Witness: drop>(self: &Oracle<Witness>): vector<TypeName> {
    self.feeds
  }

  public fun time_limit<Witness: drop>(self: &Oracle<Witness>): u64 {
    self.time_limit
  }

  public fun deviation<Witness: drop>(self: &Oracle<Witness>): u256 {
    self.deviation
  }

  // === Admin Functions ===

  public fun update_time_limit<Witness: drop>(cap: &OwnerCap<Witness>, self: &mut Oracle<Witness>, time_limit: u64) {
    owner::assert_ownership(cap, object::id(self));
    assert!(time_limit != 0, EMustHavePositiveTimeLimit);

    self.time_limit = time_limit;
  }

  public fun update_deviation<Witness: drop>(cap: &OwnerCap<Witness>, self: &mut Oracle<Witness>, deviation: u256) {
    owner::assert_ownership(cap, object::id(self));
    assert!(deviation != 0, EMustHavePositiveDeviation);

    self.deviation = deviation;
  }
}