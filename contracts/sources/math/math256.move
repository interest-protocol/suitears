/*
* @title Math u256: A set of functions to operate over u256 numbers.
* @dev Beware that some operations throw on overflow and underflows.  
*/
module suitears::math256 {
  use std::vector;

  const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

  public fun try_add(x: u256, y: u256): (bool, u256) {
    if (x == MAX_U256 && y != 0) return (false, 0);

    let rem = MAX_U256 - x;
    if (y > rem) return (false, 0);

    (true, x + y)
  }

  public fun try_sub(x: u256, y: u256): (bool, u256) {
    if (y > x) (false, 0) else (true, x - y)
  }

  public fun try_mul(x: u256, y: u256): (bool, u256) {
    if (x > MAX_U256 / y) (false, 0) else (true, x * y)
  }

  public fun try_div_down(x: u256, y: u256): (bool, u256) {
    if (y == 0) (false, 0) else (true, div_down(x, y))
  }

  public fun try_div_up(x: u256, y: u256): (bool, u256) {
    if (y == 0) (false, 0) else (true, div_up(x, y))
  }

  public fun try_mul_div_down(x: u256, y: u256, z: u256): (bool, u256) {
    if (z == 0) return (false, 0);
    let (pred, _) = try_mul(x, y);
    if (!pred) return (false, 0);

    (true, mul_div_down(x, y, z))
  }

  public fun try_mul_div_up(x: u256, y: u256, z: u256): (bool, u256) {
    if (z == 0) return (false, 0);
    let (pred, _) = try_mul(x, y);
    if (!pred) return (false, 0);

    (true, mul_div_up(x, y, z))
  }

  public fun try_mod(x: u256, y: u256): (bool, u256) {
    if (y == 0) (false, 0) else (true, x % y)
  }

  public fun mul_div_down(x: u256, y: u256, z: u256): u256 {
    x * y / z
  }

  public fun mul_div_up(x: u256, y: u256, z: u256): u256 {
    let r = mul_div_down(x, y, z);
    r + if ((x * y) % z > 0) 1 else 0
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

  // https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/math128.move
  public fun pow(n: u256, e: u256): u256 {
      if (e == 0) {
            1
        } else {
            let p = 1;
            while (e > 1) {
                if (e % 2 == 1) {
                    p = p * n;
                };
                e = e / 2;
                n = n * n;
            };
            p * n
        }
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
  public fun sqrt_down(a: u256): u256 {
    if (a == 0) return 0;

    let result = 1 << ((log2_down(a) >> 1) as u8);

    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;

    min(result, a / result)
  }

  public fun sqrt_up(value: u256): u256 {
    let r = sqrt_down(value);
    r + if (r * r < value) 1 else 0
  }

  // * Log functions from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol

  public fun log2_down(value: u256): u8 {
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

  public fun log2_up(value: u256): u8 {
    let r = log10_down(value);
    r + if (1 << (r as u8) < value) 1 else 0
  } 

  public fun log10_down(value: u256): u8 {
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

  public fun log10_up(value: u256): u8 {
    let r = log10_down(value);
    r + if (pow(10, (r as u256)) < value) 1 else 0
  }

  public fun log256_down(value: u256): u8 {
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

  public fun log256_up(value: u256): u8 {
    let r = log256_down(value);
    r + if (1 << ((r << 3)) < value) 1 else 0
  }
}