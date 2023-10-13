// Fixed Point Math without a Type guard/wrapper  
// Wad has the decimal factor as Sui - 9 decimals
module suitears::fixed_point_wad {

  use suitears::math128;

  const WAD: u128 = 1_000_000_000; // 1e9

  public fun wad(): u128 {
    WAD
  }

  public fun wad_mul_down(x: u128, y: u128): u128 {
    math128::mul_div(x, y, WAD)
  }

  public fun wad_mul_up(x: u128, y: u128): u128 {
    math128::div_up(x * y, WAD)
  }

  public fun wad_div_down(x: u128, y: u128): u128 {
    math128::mul_div(x, WAD, y)
  }

  public fun wad_div_up(x: u128, y: u128): u128 {
    math128::div_up(x * WAD, y)
  }

  public fun wad_to_ray(x: u128): u256 {
    (x as u256) * (WAD as u256)
  }
  
  public fun ray_to_wad(x: u256): u128 {
    ((x / (WAD as u256)) as u128)
  }
}