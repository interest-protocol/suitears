// Fixed Point Math without a Type guard/wrapper  
// Ray has a higher accurate and assumes values have 18 decimals
module suitears::fixed_point_wad {

  use suitears::math256;

  const WAD: u256 = 1_000_000_000_000_000_000; // 1e18
  
  public fun wad(): u256 {
    WAD
  }

  public fun wad_mul_down(x: u256, y: u256): u256 {
    math256::mul_div_down(x, y, WAD)
  }

  public fun wad_mul_up(x: u256, y: u256): u256 {
    math256::mul_div_up(x, y, WAD) 
  }

  public fun wad_div_down(x: u256, y: u256): u256 {
    math256::mul_div_down(x, WAD, y)
  }

  public fun wad_div_up(x: u256, y: u256): u256 {
    math256::div_up(x * WAD, y)
  }

  public fun to_wad(x: u256, decimal_factor: u64): u256 {
    math256::mul_div_down(x, WAD, (decimal_factor as u256))
  }
}