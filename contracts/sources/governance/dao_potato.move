module suitears::dao_potato {

  use suitears::request::{Self, RequestPotato};

  struct DaoPotato<phantom DaoOTW> has drop {}

  friend suitears::dao;

  public(friend) fun new<DaoOTW: drop>(): RequestPotato<DaoPotato<DaoOTW>> {
    request::new_potato(DaoPotato {})
  }
}