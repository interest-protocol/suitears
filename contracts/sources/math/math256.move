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

  /// Return x clamped to the interval [lower, upper].
  public fun clamp(x: u256, lower: u256, upper: u256): u256 {
    min(upper, max(lower, x))
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
  public fun sqrt(a: u256): u256 {
    if (a == 0) return 0;

    let result = 1 << ((log2(a) >> 1) as u8);

    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;

    min(result, a / result)
  }

  // * Log functions from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol

  public fun log2(value: u256): u256 {
        let result = 0;
        if (value >> 128 > 0) {
          value = value >> 128;
          result = result + 128;
        };
        
        if (value >> 64 > 0) {
            value = value >> 64;
            result = result + 64;
        };
        
        if (value >> 32 > 0) {
          value = value >> 32;
          result = result + 32;
        };
        
        if (value >> 16 > 0) {
            value = value >> 16;
            result = result + 16;
        };
        
        if (value >> 8 > 0) {
            value = value >> 8;
            result = result + 8;
        };
        
        if (value >> 4 > 0) {
            value = value >> 4;
            result = result + 4;
        };
        
        if (value >> 2 > 0) {
            value = value >> 2;
            result = result + 2;
        };
        
        if (value >> 1 > 0) 
          result = result + 1;

       result
    }

  public fun log10(value: u256): u256 {
        let result = 0;

        if (value >= 10000000000000000000000000000000000000000000000000000000000000000) {
          value = value / 10000000000000000000000000000000000000000000000000000000000000000;
          result = result + 64;
        };
        
        if (value >= 100000000000000000000000000000000) {
            value = value / 100000000000000000000000000000000;
            result = result + 16;
        };
        
        if (value >= 1000000000) {
            value = value / 100000000;
            result = result + 8;
        };
        
        if (value >= 10000) {
            value = value / 10000;
            result = result + 4;
        };
        
       if (value >= 100) {
            value = value / 100;
            result = result + 2;
        };
        
        
       if (value >= 10) 
           result = result + 1;

       result
  }

  public fun log256(value: u256): u256 {
    let result = 0;

    if (value >> 128 > 0) {
      value = value >> 128;
      result = result + 16;
    };

    if (value >> 64 > 0) {
      value = value >> 64;
      result = result + 8;
    };

    if (value >> 32 > 0) {
      value = value >> 32;
      result = result + 4;
    };

    if (value >> 8 > 0)
      result = result + 1;

    result
  }
}