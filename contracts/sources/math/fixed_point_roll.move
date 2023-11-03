// Fixed Point Math without a Type guard/wrapper  
// Wad has the decimal factor as Sui - 9 decimals
module suitears::fixed_point_roll {
  use suitears::math128;

  const ROLL: u128 = 1_000_000_000; // 1e9

  public fun roll(): u128 {
    ROLL
  }

  public fun try_roll_mul_down(x: u128, y: u128): (bool, u128) {
    math128::try_mul_div_down(x, y, ROLL)
  }

  public fun try_roll_mul_up(x: u128, y: u128): (bool, u128) {
    math128::try_mul_div_up(x, y, ROLL)
  }

  public fun try_roll_div_down(x: u128, y: u128): (bool, u128) {
    math128::try_mul_div_down(x, y, ROLL)
  }

  public fun try_roll_div_up(x: u128, y: u128): (bool, u128) {
    math128::try_mul_div_up(x, ROLL, y)
  }

  public fun roll_mul_down(x: u128, y: u128): u128 {
    math128::mul_div_down(x, y, ROLL)
  }

  public fun roll_mul_up(x: u128, y: u128): u128 {
    math128::mul_div_up(x, y, ROLL)
  }

  public fun roll_div_down(x: u128, y: u128): u128 {
    math128::mul_div_down(x, ROLL, y)
  }

  public fun roll_div_up(x: u128, y: u128): u128 {
    math128::mul_div_up(x, ROLL, y)
  }

  public fun to_roll(x: u128, decimal_factor: u64): u128 {
    math128::mul_div_down(x, ROLL, (decimal_factor as u128))
  }
}