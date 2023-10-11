// A module to easily calculate the amount of shares of an elastic pool of assets
module suimate::rebase {

  use suimate::math128::mul_div;

  struct Rebase has store, copy {
    base: u128,
    elastic: u128
  }

  public fun new(): Rebase {
    Rebase {
      base: 0,
      elastic: 0
    }
  }

  public fun base(rebase: &Rebase): u64 {
    (rebase.base as u64)
  }

  public fun elastic(rebase: &Rebase): u64 {
    (rebase.elastic as u64)
  }

  public fun to_base(rebase: &Rebase, elastic: u64, round_up: bool): u64 {
    if (rebase.elastic == 0) { elastic } else {
      let base = mul_div((elastic as u128), rebase.base, rebase.elastic); 
      if (round_up && (mul_div(base, rebase.elastic, rebase.base) < (elastic as u128))) base = base + 1;
      (base as u64)
    }
  }

  public fun to_elastic(rebase: &Rebase, base: u64, round_up: bool): u64 {
    if (rebase.base == 0) { base } else {
        let elastic = mul_div((base as u128), rebase.elastic, rebase.base); 
        if (round_up && (mul_div(elastic, rebase.base, rebase.elastic) < (base as u128))) elastic = elastic + 1;
        (elastic as u64)
    }
  }

  public fun sub_base(rebase: &mut Rebase, base: u64, round_up: bool): u64 {
    let elastic = to_elastic(rebase, base, round_up);
    rebase.elastic = rebase.elastic - (elastic as u128);
    rebase.base = rebase.base - (base as u128);
    elastic
  }

  public fun add_elastic(rebase: &mut Rebase, elastic: u64, round_up: bool): u64 {
    let base = to_base(rebase, elastic, round_up);
    rebase.elastic = rebase.elastic + (elastic as u128);
    rebase.base = rebase.base + (base as u128);
    base
  }

  public fun sub_elastic(rebase: &mut Rebase, elastic: u64, round_up: bool): u64 {
    let base = to_base(rebase, elastic, round_up);
    rebase.elastic = rebase.elastic - (elastic as u128);
    rebase.base = rebase.base - (base as u128);
    base
  }

  public fun set_elastic(rebase: &mut Rebase, elastic: u64) {
    rebase.elastic = (elastic as u128);
  }  
}