// Fixed Point Math without a Type guard/wrapper  
// Wad has the decimal factor as Sui - 9 decimals
module suitears::fixed_point_roll {

  use suitears::math128;
  use suitears::math256;

  const ROLL: u128 = 1_000_000_000; // 1e9

  public fun roll(): u128 {
    ROLL
  }

  public fun roll_mul_down(x: u128, y: u128): u128 {
    math128::mul_div_down(x, y, ROLL)
  }

  public fun roll_mul_up(x: u128, y: u128): u128 {
    (math256::div_up((x as u256) * (y as u256), (ROLL as u256)) as u128)
  }

  public fun roll_div_down(x: u128, y: u128): u128 {
    math128::mul_div_down(x, ROLL, y)
  }

  public fun roll_div_up(x: u128, y: u128): u128 {
    math128::div_up(x * ROLL, y)
  }

  public fun to_roll(x: u256, decimal_factor: u64): u64 {
    (math256::mul_div_down(x, (ROLL as u256), (decimal_factor as u256)) as u64)
  }
}