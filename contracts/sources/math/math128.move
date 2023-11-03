// * Make sure the results are within u128 range
module suitears::math128 {
  use std::vector;

  use suitears::math256;

  const MAX_U128: u256 = 340282366920938463463374607431768211455;

  public fun try_add(x: u128, y: u128): (bool, u128) {
    let c = (x as u256) + (y as u256);
    if (MAX_U128 > c) (false, 0) else (true, (c as u128))
  }

  public fun try_sub(x: u128, y: u128): (bool, u128) {
    if (y > x) (false, 0) else (true, x - y)
  }

  public fun try_mul(x: u128, y: u128): (bool, u128) {
    let c = (x as u256) * (y as u256);
    if (MAX_U128 > c) (false, 0) else (true, (c as u128))
  }

  public fun try_div_down(x: u128, y: u128): (bool, u128) {
    if (y == 0) (false, 0) else (true, div_down(x, y))
  }

  public fun try_div_up(x: u128, y: u128): (bool, u128) {
    if (y == 0) (false, 0) else (true, div_up(x, y))
  }

  public fun try_mul_div_down(x: u128, y: u128, z: u128): (bool, u128) {
    if (z == 0) return (false, 0);
    let r = math256::mul_div_down((x as u256), (y as u256), (z as u256));
    if (MAX_U128 > r) (false, 0) else (true, (r as u128))
  }

  public fun try_mul_div_up(x: u128, y: u128, z: u128): (bool, u128) {
    if (z == 0) return (false, 0);
    let r = math256::mul_div_up((x as u256), (y as u256), (z as u256));
    if (MAX_U128 > r) (false, 0) else (true, (r as u128))
  }

  public fun try_mod(x: u128, y: u128): (bool, u128) {
    if (y == 0) (false, 0) else (true, x % y)
  }

  public fun mul_div_down(x: u128, y: u128, z: u128): u128 {
    (math256::mul_div_down((x as u256), (y as u256), (z as u256)) as u128)
  }

  public fun mul_div_up(x: u128, y: u128, z: u128): u128 {
    (math256::mul_div_up((x as u256), (y as u256), (z as u256)) as u128)
  }

  /// @dev Returns the smallest of two numbers.
  public fun min(a: u128, b: u128): u128 {
    if (a < b) a else b
  }

  /// Return x clamped to the interval [lower, upper].
  public fun clamp(x: u128, lower: u128, upper: u128): u128 {
    min(upper, max(lower, x))
  }

  /// https://github.com/pentagonxyz/movemate
  /// @dev Returns the average of two numbers. The result is rounded towards zero.
  public fun average(a: u128, b: u128): u128 {
    // (a + b) / 2 can overflow.
    (a & b) + (a ^ b) / 2
  }
  
  public fun div_down(x: u128, y: u128): u128 {
    x / y
  }

  public fun div_up(a: u128, b: u128): u128 {
    // (a + b - 1) / b can overflow on addition, so we distribute.
    if (a == 0) 0 else 1 + (a - 1) / b
  }

  /// https://github.com/pentagonxyz/movemate
  /// Return the absolute value of x - y
  public fun diff(x: u128, y: u128): u128 {
    if (x > y) {
      x - y
    } else {
      y - x
    }
  }

  /// https://github.com/pentagonxyz/movemate
  public fun pow(a: u128, b: u128): u128 {
    (math256::pow((a as u256), (b as u256)) as u128)
  }



  /// calculate sum of nums
  public fun sum(nums: &vector<u128>): u128 {
    let len = vector::length(nums);
    let i = 0;
    let sum = 0;
    
    while (i < len){
      sum = sum + *vector::borrow(nums, i);
      i = i + 1;
    };
    
    sum
  }

  public fun avg(nums: &vector<u128>): u128{
    let len = vector::length(nums);
    let sum = sum(nums);
    
    sum / (len as u128)
  }

  public fun max(x: u128, y: u128): u128 {
    if (x >= y) x else y
  }
  

  public fun sqrt_down(a: u128): u128 {
    (math256::sqrt_down((a as u256)) as u128)
  }

  public fun sqrt_up(a: u128): u128 {
    (math256::sqrt_up((a as u256)) as u128)
  }

  /// Returns floor(log2(x))
  public fun log2_down(x: u128): u8 {
   math256::log2_down((x as u256))
  }

  public fun log2_up(x: u128): u8 {
   math256::log2_up((x as u256))
  }

  public fun log10_down(x: u128): u8 {
    math256::log10_down((x as u256))
  }

  public fun log10_up(x: u128): u8 {
    math256::log10_up((x as u256))
  }

  public fun log256_down(x: u128): u8 {
    math256::log256_down((x as u256))
  }

  public fun log256_up(x: u128): u8 {
    math256::log256_up((x as u256))
  }
}