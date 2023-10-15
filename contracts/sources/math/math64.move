module suitears::math64 {
  use std::vector;

  use suitears::math256;

  const QUADRATIC_SCALAR: u64 = 1 << 16;

  public fun mul_div(x: u64, y: u64, z: u64): u64 {
    (math256::mul_div((x as u256), (y as u256), (z as u256)) as u64)
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
    let c = 1;

    while (n > 0) {
      if (n & 1 > 0) c = c * x;
        n = n >> 1;
        x = x * x;
      };

    c
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
  
  /// Source: https://github.com/pentagonxyz/movemate/blob/main/sui/sources/math_u64.move
  /// @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
  /// Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
  /// Costs only 9 gas in comparison to the 16 gas `sui::math::sqrt` costs (tested on Aptos).
  public fun sqrt(a: u64): u64 {
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
}