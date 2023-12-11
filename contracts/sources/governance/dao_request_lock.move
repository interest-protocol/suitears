module suitears::dao_request_lock {

  use suitears::request_lock::{Self, Lock};

  struct Issuer<phantom DaoOTW> has drop {}

  friend suitears::dao;

  public(friend) fun new<DaoOTW: drop>(): Lock<Issuer<DaoOTW>> {
    request_lock::new_lock(Issuer {})
  }
}