module suitears::math256 {
  use std::vector;

  public fun mul_div_down(x: u256, y: u256, z: u256): u256 {
    x * y / z
  }

  public fun mul_div_up(x: u256, y: u256, z: u256): u256 {
    div_up(x * y, z)
  }

  /// @dev Returns the smallest of two numbers.
  public fun min(a: u256, b: u256): u256 {
    if (a < b) a else b
  }

  /// https://github.com/pentagonxyz/movemate
  /// @dev Returns the average of two numbers. The result is rounded towards zero.
  public fun average(a: u256, b: u256): u256 {
    // (a + b) / 2 can overflow.
    (a & b) + (a ^ b) / 2
  }

  // API convenience
  public fun mul(x: u256, y: u256): u256 {
    x * y
  }
  
  public fun div_down(x: u256, y: u256): u256 {
    x / y
  }

  public fun div_up(a: u256, b: u256): u256 {
    // (a + b - 1) / b can overflow on addition, so we distribute.
    if (a == 0) 0 else 1 + (a - 1) / b
  }

  /// https://github.com/pentagonxyz/movemate
  /// Return the absolute value of x - y
  public fun diff(x: u256, y: u256): u256 {
    if (x > y) {
      x - y
    } else {
      y - x
    }
  }

  /// https://github.com/pentagonxyz/movemate
  public fun pow(a: u256, b: u128): u256 {
    let c = 1;

    while (b > 0) {
      if (b & 1 > 0) c = c * a;
        b = b >> 1;
        a = a * a;
      };

    c
  }

  /// calculate sum of nums
  public fun sum(nums: &vector<u256>): u256 {
    let len = vector::length(nums);
    let i = 0;
    let sum = 0;
    
    while (i < len){
      sum = sum + *vector::borrow(nums, i);
      i = i + 1;
    };
    
    sum
  }

  public fun avg(nums: &vector<u256>): u256{
    let len = vector::length(nums);
    let sum = sum(nums);
    
    sum / (len as u256)
  }

  public fun max(x: u256, y: u256): u256 {
    if (x >= y) x else y
  }
  
  /// @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
  /// Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
  /// Costs only 9 gas in comparison to the 16 gas `sui::math::sqrt` costs (tested on Aptos).
  public fun sqrt(y: u256): u256 {
    let z = 0;
    if (y > 3) {
      z = y;
      let x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    };
    z
  }
}