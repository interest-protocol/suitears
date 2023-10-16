// Fixed Point Math without a Type guard/wrapper  
// Wad has the decimal factor as Sui - 9 decimals
module suitears::fixed_point_wad {

  use suitears::math128;
  use suitears::math256;

  const WAD: u128 = 1_000_000_000; // 1e9

  public fun wad(): u128 {
    WAD
  }

  public fun wad_mul_down(x: u128, y: u128): u128 {
    math128::mul_div_down(x, y, WAD)
  }

  public fun wad_mul_up(x: u128, y: u128): u128 {
    (math256::div_up((x as u256) * (y as u256), (WAD as u256)) as u128)
  }

  public fun wad_div_down(x: u128, y: u128): u128 {
    math128::mul_div_down(x, WAD, y)
  }

  public fun wad_div_up(x: u128, y: u128): u128 {
    math128::div_up(x * WAD, y)
  }

  public fun to_wad(x: u256, decimal_factor: u64): u64 {
    (math256::mul_div_down(x, (WAD as u256), (decimal_factor as u256)) as u64)
  }
}