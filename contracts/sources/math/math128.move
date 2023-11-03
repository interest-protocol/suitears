module suitears::math128 {
  use std::vector;

  use suitears::math256;

  const EInvalidArgFloorLog2: u64 = 0;

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
    let c = 1;

    while (b > 0) {
      if (b & 1 > 0) c = c * a;
        b = b >> 1;
        a = a * a;
      };

    c
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
  
  /// https://github.com/pentagonxyz/movemate
  /// @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
  /// Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
  /// Costs only 9 gas in comparison to the 16 gas `sui::math::sqrt` costs (tested on Aptos).
  public fun sqrt(a: u128): u128 {
    if (a == 0) {
      return 0
    };

    // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
    // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
    // `msb(a) <= a < 2*msb(a)`.
    // We also know that `k`, the position of the most significant bit, is such that `msb(a) = 2**k`.
    // This gives `2**k < a <= 2**(k+1)` => `2**(k/2) <= sqrt(a) < 2 ** (k/2+1)`.
    // Using an algorithm similar to the msb computation, we are able to compute `result = 2**(k/2)` which is a
    // good first approximation of `sqrt(a)` with at least 1 correct bit.
    let result = 1;
    let x = a;
    if (x >> 64 > 0) {
      x = x >> 64;
      result = result << 32;
    };
    if (x >> 32 > 0) {
      x = x >> 32;
      result = result << 16;
    };
    if (x >> 16 > 0) {
        x = x >> 16;
        result = result << 8;
    };
    if (x >> 8 > 0) {
      x = x >> 8;
      result = result << 4;
    };
    
    if (x >> 4 > 0) {
      x = x >> 4;
      result = result << 2;
    };
    if (x >> 2 > 0) {
      result = result << 1;
    };

    // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
    // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
    // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
    // into the expected uint128 result.
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    min(result, a / result)
  }

  /// Returns floor(log2(x))
    public fun floor_log2(x: u128): u8 {
        let res = 0;
        assert!(x != 0, EInvalidArgFloorLog2);
        // Effectively the position of the most significant set bit
        let n = 64;
        while (n > 0) {
            if (x >= (1 << n)) {
                x = x >> n;
                res = res + n;
            };
            n = n >> 1;
        };
        res
    }
}