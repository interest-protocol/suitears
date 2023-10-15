// A module to easily calculate the amount of shares of an underlying pool of assets
module suitears::fund {

  use suitears::math128::mul_div;

  struct Fund has store, copy {
    shares: u128,
    underlying: u128
  }

  public fun empty(): Fund {
    Fund {
      shares: 0,
      underlying: 0
    }
  }

  public fun shares(rebase: &Fund): u64 {
    (rebase.shares as u64)
  }

  public fun underlying(rebase: &Fund): u64 {
    (rebase.underlying as u64)
  }

  public fun to_shares(rebase: &Fund, underlying: u64, round_up: bool): u64 {
    if (rebase.underlying == 0) { underlying } else {
      let shares = mul_div((underlying as u128), rebase.shares, rebase.underlying); 
      if (round_up && (mul_div(shares, rebase.underlying, rebase.shares) < (underlying as u128))) shares = shares + 1;
      (shares as u64)
    }
  }

  public fun to_underlying(rebase: &Fund, shares: u64, round_up: bool): u64 {
    if (rebase.shares == 0) { shares } else {
        let underlying = mul_div((shares as u128), rebase.underlying, rebase.shares); 
        if (round_up && (mul_div(underlying, rebase.shares, rebase.underlying) < (shares as u128))) underlying = underlying + 1;
        (underlying as u64)
    }
  }

  public fun sub_shares(rebase: &mut Fund, shares: u64, round_up: bool): u64 {
    let underlying = to_underlying(rebase, shares, round_up);
    rebase.underlying = rebase.underlying - (underlying as u128);
    rebase.shares = rebase.shares - (shares as u128);
    underlying
  }

  public fun add_underlying(rebase: &mut Fund, underlying: u64, round_up: bool): u64 {
    let shares = to_shares(rebase, underlying, round_up);
    rebase.underlying = rebase.underlying + (underlying as u128);
    rebase.shares = rebase.shares + (shares as u128);
    shares
  }

  public fun sub_underlying(rebase: &mut Fund, underlying: u64, round_up: bool): u64 {
    let shares = to_shares(rebase, underlying, round_up);
    rebase.underlying = rebase.underlying - (underlying as u128);
    rebase.shares = rebase.shares - (shares as u128);
    shares
  }

  public fun set_underlying(rebase: &mut Fund, underlying: u64) {
    rebase.underlying = (underlying as u128);
  }  
}