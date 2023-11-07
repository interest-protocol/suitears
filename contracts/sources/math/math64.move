// * Make sure the results are within u64 range
module suitears::math64 {
  use std::vector;

  use suitears::int;
  use suitears::math256;

  const QUADRATIC_SCALAR: u64 = 1 << 16;

  const MAX_U64: u256 = 18446744073709551615;
  const WRAPPING_MAX: u256 = 18446744073709551616; // MAX_U64 + 1

  public fun wrapping_add(x: u64, y: u64): u64 {
    (math256::wrap_number(
      int::add(int::from_u64(x), int::from_u64(y)),
      WRAPPING_MAX
    ) as u64)
  }

  public fun wrapping_sub(x: u64, y: u64): u64 {
    (math256::wrap_number(
      int::sub(int::from_u64(x), int::from_u64(y)),
      WRAPPING_MAX
    ) as u64)
  }

  public fun wrapping_mul(x: u64, y: u64): u64 {
    (math256::wrap_number(
      int::mul(int::from_u64(x), int::from_u64(y)),
      WRAPPING_MAX
    ) as u64)
  }

  public fun try_add(x: u64, y: u64): (bool, u64) {
    let c = (x as u256) + (y as u256);
    if (MAX_U64 > c) (false, 0) else (true, (c as u64))
  }

  public fun try_sub(x: u64, y: u64): (bool, u64) {
    if (y > x) (false, 0) else (true, x - y)
  }

  public fun try_mul(x: u64, y: u64): (bool, u64) {
    let (pred, c) = math256::try_mul((x as u256), (y as u256));
    if (!pred || MAX_U64 > c) (false, 0) else (true, (c as u64))
  }

  public fun try_div_down(x: u64, y: u64): (bool, u64) {
    if (y == 0) (false, 0) else (true, div_down(x, y))
  }

  public fun try_div_up(x: u64, y: u64): (bool, u64) {
    if (y == 0) (false, 0) else (true, div_up(x, y))
  }

  public fun try_mul_div_down(x: u64, y: u64, z: u64): (bool, u64) {
    let (pred, r) = math256::try_mul_div_down((x as u256), (y as u256), (z as u256));
    if (!pred || MAX_U64 > r) (false, 0) else (true, (r as u64))
  }

  public fun try_mul_div_up(x: u64, y: u64, z: u64): (bool, u64) {
    let (pred, r) = math256::try_mul_div_up((x as u256), (y as u256), (z as u256));
    if (!pred || MAX_U64 > r) (false, 0) else (true, (r as u64))
  }

  public fun try_mod(x: u64, y: u64): (bool, u64) {
    if (y == 0) (false, 0) else (true, x % y)
  }

  public fun mul_div_down(x: u64, y: u64, z: u64): u64 {
    (math256::mul_div_down((x as u256), (y as u256), (z as u256)) as u64)
  }

  public fun mul_div_up(x: u64, y: u64, z: u64): u64 {
    (math256::mul_div_up((x as u256), (y as u256), (z as u256)) as u64)
  }  

  /// @dev Returns the smallest of two numbers.
  public fun min(x: u64, y: u64): u64 {
    if (x < y) x else y
  }

  /// SRC https://github.com/pentagonxyz/movemate/blob/main/sui/sources/math_u64.move
  /// @dev Returns the average of two numbers. The result is rounded towards zero.
  public fun average(x: u64, y: u64): u64 {
    // (a + b) / 2 can overflow.
    (x & y) + (x ^ y) / 2
  }

  public fun div_down(x: u64, y: u64): u64 {
    x / y
  }

  public fun div_up(a: u64, b: u64): u64 {
    // (a + b - 1) / b can overflow on addition, so we distribute.
    if (a == 0) 0 else 1 + (a - 1) / b
  }

  /// SRC https://github.com/pentagonxyz/movemate/blob/main/sui/sources/math_u64.move
  /// Return the absolute value of x - y
  public fun diff(x: u64, y: u64): u64 {
    if (x > y) {
      x - y
    } else {
      y - x
    }
  }

  /// SRC https://github.com/pentagonxyz/movemate/blob/main/sui/sources/math_u64.move
  public fun pow(x: u64, n: u64): u64 {
    (math256::pow((x as u256), (n as u256)) as u64)
  }

  /// calculate sum of nums
  public fun sum(nums: &vector<u64>): u64 {
    let len = vector::length(nums);
    let i = 0;
    let sum = 0;
    
    while (i < len){
      sum = sum + *vector::borrow(nums, i);
      i = i + 1;
    };
    
    sum
  }

    /// Return x clamped to the interval [lower, upper].
  public fun clamp(x: u64, lower: u64, upper: u64): u64 {
    min(upper, max(lower, x))
  }

  public fun avg(nums: &vector<u64>): u64{
    let len = vector::length(nums);
    let sum = sum(nums);
    
    sum / (len as u64)
  }

  public fun max(x: u64, y: u64): u64 {
    if (x >= y) x else y
  }

  public fun quadratic_scalar(): u64 {
    QUADRATIC_SCALAR
  }

  /// @notice Calculates ax^2 + bx + c assuming all variables are scaled by 2**16.
  public fun quadratic(x: u64, a: u64, b: u64, c: u64): u64 {
    (pow(x, 2) / QUADRATIC_SCALAR * a / QUADRATIC_SCALAR) + (b * x / QUADRATIC_SCALAR) + c
  }
  
  public fun sqrt_down(a: u64): u64 {
    (math256::sqrt_down((a as u256)) as u64)
  }

  public fun sqrt_up(a: u64): u64 {
    (math256::sqrt_up((a as u256)) as u64)
  }

  public fun log2_down(value: u64): u8 {
    math256::log2_down((value as u256))
  }

  public fun log2_up(value: u64): u8 {
    math256::log2_up((value as u256))
  }

  public fun log10_down(value: u64): u8 {
    math256::log10_down((value as u256))
  }

  public fun log10_up(value: u64): u8 {
    math256::log10_up((value as u256))
  }
}