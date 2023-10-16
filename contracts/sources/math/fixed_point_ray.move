// Fixed Point Math without a Type guard/wrapper  
// Ray has a higher accurate and assumes values have 18 decimals
module suitears::fixed_point_ray {

  use suitears::math256;

  const RAY: u256 = 1_000_000_000_000_000_000; // 1e18
  
  public fun ray(): u256 {
    RAY
  }

  public fun ray_mul_down(x: u256, y: u256): u256 {
    math256::mul_div_down(x, y, RAY)
  }

  public fun ray_mul_up(x: u256, y: u256): u256 {
    math256::mul_div_up(x, y, RAY) 
  }

  public fun ray_div_down(x: u256, y: u256): u256 {
    math256::mul_div_down(x, RAY, y)
  }

  public fun ray_div_up(x: u256, y: u256): u256 {
    math256::div_up(x * RAY, y)
  }

  public fun to_ray(x: u256, decimal_factor: u64): u256 {
    math256::mul_div_down(x, RAY, (decimal_factor as u256))
  }
}