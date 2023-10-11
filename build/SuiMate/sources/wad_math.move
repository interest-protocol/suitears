module suimate::wad_math {

  use suimate::math128;
  use suimate::math256;

  const WAD: u128 = 1_000_000_000; // 1e9
  const RAY: u256 = 1_000_000_000_000_000_000; // 1e18

  public fun wad(): u128 {
    WAD
  }

  public fun ray(): u256 {
    RAY
  }

  public fun wad_mul(x: u128, y: u128): u128 {
    math128::mul_div(x, y, WAD)
  }

  public fun wad_mul_up(x: u128, y: u128): u128 {
    math128::mul_div_up(x, y, WAD)  
  }

  public fun wad_div(x: u128, y: u128): u128 {
    math128::mul_div(x, WAD, y)
  }

  public fun wad_div_up(x: u128, y: u128): u128 {
    math128::mul_div_up(x, WAD, y)
  }

  public fun ray_mul(x: u256, y: u256): u256 {
    math256::mul_div(x, y, RAY)
  }

  public fun ray_mul_up(x: u256, y: u256): u256 {
    math256::mul_div_up(x, y, RAY)
  }

  public fun ray_div(x: u256, y: u256): u256 {
    math256::mul_div(x, RAY, y)
  }

  public fun ray_div_up(x: u256, y: u256): u256 {
    math256::mul_div_up(x, RAY, y)
  }

  public fun to_wad(x: u128): u128 {
    x * WAD
  }

  public fun to_ray(x: u256): u256 {
    x * RAY
  }

  public fun wad_to_ray(x: u128): u256 {
    (x as u256) * (WAD as u256)
  }
  
  public fun ray_to_wad(x: u256): u128 {
    ((x / (WAD as u256)) as u128)
  }
}