/*
* @title Oracle
*
* @notice Creates an `Oracle` that collects price reports from several feeds and ensures they are withing a price range and time limit. 
*
* @dev The flow:  
* - Request a hot potato to collect price feeds.  
* - Destroy the `Request` to get the `Price` hot potato.  
* - Pass the `Price` into the dApp that requires the price.  
* - dApp destroys the `Price` to get the price reported.  
*/
module suitears::oracle {
  // === Imports ===

  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::transfer;
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::vec_set::{Self, VecSet};
  use sui::object::{Self, UID, ID};  

  use suitears::math256;
  use suitears::vectors;
  use suitears::owner::{Self, OwnerCap};

  // === Errors ===

  const EOracleMustHaveFeeds: u64 = 0;
  const EMustHavePositiveTimeLimit: u64 = 1;
  const EMustHavePositiveDeviation: u64 = 2;
  const ERequestAndOracleIdMismatch: u64 = 3;
  const EWrongNumberOfReports: u64 = 4;
  const EInvalidReportFeeds: u64 = 5;
  const EStalePriceReport: u64 = 6;
  const EPriceCannotBeZero: u64 = 7;
  const EPriceDeviationIsTooHigh: u64 =  8;

  // === Constants ===

  const WAD: u256 = 1_000_000_000_000_000_000; // 1e18  

  // === Structs ===

  struct Oracle<phantom Witness: drop> has key, store {
    id: UID,
    // Set of module Witnesses that are allowed to report prices.
    feeds: VecSet<TypeName>,
    // Reported prices must have a timestamp earlier than `current_timestamp - time_limit`. 
    // It is in milliseconds. 
    time_limit: u64,
    // Reported prices must be within the following range: `leader_price + deviation % >= reported_price >= leader_price - deviation %`.
    deviation: u256
  }  

  struct Report has store, copy, drop {
    // Price  has 18 decimals.  
    price: u256,
    // Timestamp in milliseconds. 
    timestamp: u64
  }

  struct Request {
    // `sui::object::ID` of the`Oracle` this request was sent from.
    oracle: ID,
    // Set of Witnesses that reported the price. 
    feeds: VecSet<TypeName>,
    // The price reports. 
    reports: vector<Report>
  }

  struct Price {
    // `sui::object::ID` of the`Oracle` this request was sent from.
    oracle: ID,
    // The first reported price. 
    // Price has 18 decimals.  
    price: u256,
    // It is always 18.  
    decimals: u8, 
    // The price was reported at this time.  
    timestamp: u64    
  }

  // === Public-Mutative Functions ===

  /*
  * @notice Creates an `Oracle` with a set of feeds.  
  *
  * @dev The `Oracle` is designed to handle the price for one asset. 
  *
  * @param cap An owner cap from `suitears::owner`. This `OwnerCap` will be the owner of the new `Oracle`.    
  * @param wit A Witness from the module that will manage this `Oracle`.  
  * @param feeds Feed Witnesses. Only modules in the `Oracle.feeds` can report a price in the `Request` hot potato.  
  * @param time_limit A time in milliseconds that determines how old a price timestamp can be.  
  * @param deviation A percentage that determines an acceptable price range for all reported prices. 
  * @return Oracle. 
  *
  * aborts-if:  
  * - `feeds` vector is empty. As an Oracle needs at least one price feed.   
  * - `feeds` vector has repeated values.
  * - `time_limit` must be higher than 0 milliseconds.  
  * - `deviation` must be higher than 0. 
  */
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
      feeds: vectors::to_vec_set(feeds),
      time_limit,
      deviation
    };

    owner::add(cap, wit, object::id(&oracle));

    oracle
  }

  /*
  * @notice Shares the `Oracle` object. 
  *
  * @dev Sharing is irreversible. 
  *
  * @param self The `Oracle`.  
  */
  #[lint_allow(share_owned, custom_state_change)]
  public fun share<Witness: drop>(self: Oracle<Witness>) {
    transfer::share_object(self);
  }

  /*
  * @notice Creates a `Request` hot potato. 
  *
  * @param self The `Request` will require all feeds from `Oracle` to be reported.  
  * @return `Request`.  
  */
  public fun request<Witness: drop>(self: &Oracle<Witness>): Request {
    Request {
      oracle: object::id(self),
      feeds: vec_set::empty(),
      reports: vector[],
    }
  }

  /*
  * @notice Adds a price `Report` to the `Request`. 
  *
  * @dev It scales the `price` to 18 decimal houses. The feeds do not need to be reported in the same order as the feeds property in the `Oracle`.  
  *
  * @param request `Request` hot potato.  
  * @param _ A Witness to verify the reporters.  
  * @param timestamp The timestamp of the price feed.  
  * @param price The price 
  * @param decimals The decimal houses of the `price` value. 
  * @return `Request`.  
  *
  * aborts-if  
  * - a feed reports more than once.   
  */
  public fun report<Witness: drop>(request: &mut Request, _: Witness, timestamp: u64, price: u128, decimals: u8) {
    vec_set::insert(&mut request.feeds, type_name::get<Witness>());
    vector::push_back(&mut request.reports, Report { 
      price: math256::mul_div_down((price as u256), WAD, math256::pow(10, (decimals as u256))),
      timestamp
     });
  }

  /*
  * @notice Destroy the `Request` potato and verify the price values and timestamps. 
  *
  * @param self The `Oracle` that the `Request` was sent from.   
  * @param request The `Request`. 
  * @param c The shared `sui::clock::Clock` object. 
  * @return `Price`.  
  *
  * aborts-if  
  * - the `Request.oracle` does not match the `self.id`.    
  * - the number of reports does not match the number of feeds in the `Oracle.feeds`.  
  * - the report witnesses do not match the required feed witnesses.  
  * - a reported price is outside the `time_limit`.   
  * - a price falls outside the outside `deviation` range.
  */
  public fun destroy_request<Witness: drop>(self: &Oracle<Witness>, request: Request, c: &Clock): Price {
    let Request { oracle, reports, feeds } = request;  

    assert!(oracle == object::id(self), ERequestAndOracleIdMismatch);

    let num_of_feeds = vec_set::size(&self.feeds);
    let num_of_reports = vector::length(&reports);

    assert!(num_of_feeds == num_of_reports, EWrongNumberOfReports);

    let i = 0;
    let leader_price = 0;
    let leader_timestamp = 0;
    let current_time = clock::timestamp_ms(c);

    let oracle_feeds = vec_set::into_keys(self.feeds);
    let report_feeds = vec_set::into_keys(feeds);

    while (num_of_feeds > i) {
      let feed = *vector::borrow(&oracle_feeds, i);
      let report = *vector::borrow(&reports, i);   

      assert!(vector::contains(&report_feeds, &feed), EInvalidReportFeeds);
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

  /*
  * @notice Destroys a `Price` potato and unpacks the values. 
  *
  * @param price `Price` hot potato.   
  * @return ID An `Oracle` ID.  
  * @return u256 A price.  
  * @return u8 The decimal values of the price.  
  * @return u64 The timestamp of the price.   
  */
  public fun destroy_price(price: Price): (ID, u256, u8, u64) {
    let Price { oracle, price,decimals, timestamp } = price;
    (oracle, price, decimals, timestamp)
  }

  // === Public-View Functions ===

  /*
  * @notice Returns a vector of the `Oracle.feeds`. 
  *
  * @param self An `Oracle` object.  
  * @return vector<TypeNames>  
  */
  public fun feeds<Witness: drop>(self: &Oracle<Witness>): vector<TypeName> {
    vec_set::into_keys(self.feeds)
  }

  /*
  * @notice Returns a time limit set in the `Oracle`. 
  *
  * @param self An `Oracle` object.  
  * @return u64 
  */
  public fun time_limit<Witness: drop>(self: &Oracle<Witness>): u64 {
    self.time_limit
  }

  /*
  * @notice Returns the price deviation set in the `Oracle`. 
  *
  * @param self An `Oracle` object.  
  * @return u256
  */
  public fun deviation<Witness: drop>(self: &Oracle<Witness>): u256 {
    self.deviation
  }

  // === Admin Functions ===

  /*
  * @notice Adds a feed Witness to an `Oracle`. 
  *
  * @cap The `suitears::owner::OwnerCap` that owns the `self`.  
  * @param self An `Oracle` object.  
  * @param feed A Witness feed.    
  *
  * aborts-if:  
  * - a duplicated `feed` is added.  
  */
  public fun add<Witness: drop>(cap: &OwnerCap<Witness>, self: &mut Oracle<Witness>, feed: TypeName) {
    owner::assert_ownership(cap, object::id(self));

    vec_set::insert(&mut self.feeds, feed);
  }  

  /*
  * @notice Removes a feed Witness from an `Oracle`. 
  *
  * @cap The `suitears::owner::OwnerCap` that owns the `self`.  
  * @param self An `Oracle` object.  
  * @param feed A Witness feed.    
  *
  * aborts-if:  
  * - the `cap` is not the owner of `self`.  
  * - the `Oracle` has 1 feed left.  
  */
  public fun remove<Witness: drop>(cap: &OwnerCap<Witness>, self: &mut Oracle<Witness>, feed: TypeName) {
    assert!(vec_set::size(&self.feeds) > 1, EOracleMustHaveFeeds);
    owner::assert_ownership(cap, object::id(self));

    vec_set::remove(&mut self.feeds, &feed);
  }    

  /*
  * @notice Updates the time_limit of an `Oracle`. 
  *
  * @cap The `suitears::owner::OwnerCap` that owns the `self`.  
  * @param self An `Oracle` object.  
  * @param time_limit The new time_limit.     
  *
  * aborts-if:  
  * - the `cap` is not the owner of `self`.    
  * - the `time_limit` cannot be zero. 
  */
  public fun update_time_limit<Witness: drop>(cap: &OwnerCap<Witness>, self: &mut Oracle<Witness>, time_limit: u64) {
    owner::assert_ownership(cap, object::id(self));
    assert!(time_limit != 0, EMustHavePositiveTimeLimit);

    self.time_limit = time_limit;
  }

  /*
  * @notice Updates the deviation of an `Oracle`. 
  *
  * @cap The `suitears::owner::OwnerCap` that owns the `self`.  
  * @param self An `Oracle` object.  
  * @param deviation The new deviation.   
  *
  * aborts-if:  
  * - the `cap` is not the owner of `self`.    
  * - the `deviation` is zero.  
  */
  public fun update_deviation<Witness: drop>(cap: &OwnerCap<Witness>, self: &mut Oracle<Witness>, deviation: u256) {
    owner::assert_ownership(cap, object::id(self));
    assert!(deviation != 0, EMustHavePositiveDeviation);

    self.deviation = deviation;
  }  
}