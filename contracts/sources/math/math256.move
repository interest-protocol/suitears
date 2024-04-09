/*
* @title Math256
*
* @notice A set of functions to operate over u256 numbers.
* @notice Many functions are implementations of https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol
*
* @dev Beware that some operations throw on overflow and underflows.  
*/
module suitears::math256 {
  // === Imports ===

  use std::vector;

  // === Constants ===

  // @dev Maximum U256 number
  const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

  // === Try Functions do not throw ===

  /*
  * @notice It tries to perform `x` + `y`.
  * 
  * @dev Checks for overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u256. The result of `x` + `y`. If it fails, it will be 0. 
  */
  public fun try_add(x: u256, y: u256): (bool, u256) {
    if (x == MAX_U256 && y != 0) return (false, 0);

    let rem = MAX_U256 - x;
    if (y > rem) return (false, 0);

    (true, x + y)
  }

  /*
  * @notice It tries to perform `x` - `y`. 
  *
  * @dev Checks for underflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u256. The result of `x` - `y`. If it fails, it will be 0. 
  */
  public fun try_sub(x: u256, y: u256): (bool, u256) {
    if (y > x) (false, 0) else (true, x - y)
  }

  /*
  * @notice It tries to perform `x` * `y`. 
  *
  * @dev Checks for overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u256. The result of `x` * `y`. If it fails, it will be 0. 
  */
  public fun try_mul(x: u256, y: u256): (bool, u256) {
    if (y == 0) return (true, 0);
    if (x > MAX_U256 / y) (false, 0) else (true, x * y)
  }

  /*
  * @notice It tries to perform `x` / `y rounding down. 
  *
  * @dev Checks for zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u256. The result of x / y. If it fails, it will be 0. 
  */
  public fun try_div_down(x: u256, y: u256): (bool, u256) {
    if (y == 0) (false, 0) else (true, div_down(x, y))
  }

  /*
  * @notice It tries to perform `x` / `y` rounding up. 
  *
  * @dev Checks for zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u256. The result of `x` / `y`. If it fails, it will be 0. 
  */
  public fun try_div_up(x: u256, y: u256): (bool, u256) {
    if (y == 0) (false, 0) else (true, div_up(x, y))
  }

  /*
  * @notice It tries to perform `x` * `y` / `z` rounding down. 
  *
  * @dev Checks for zero division. 
  * @dev Checks for overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @param z The divisor. 
  * @return bool. If the operation was successful.
  * @return u256. The result of `x` * `y` / `z`. If it fails, it will be 0. 
  */
  public fun try_mul_div_down(x: u256, y: u256, z: u256): (bool, u256) {
    if (z == 0) return (false, 0);
    let (pred, _) = try_mul(x, y);
    if (!pred) return (false, 0);

    (true, mul_div_down(x, y, z))
  }

  /*
  * @notice It tries to perform `x` * `y` / `z` rounding up. 
  *
  * @dev Checks for zero division. 
  * @dev Checks for overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @param z The divisor. 
  * @return bool. If the operation was successful.
  * @return u256. The result of `x` * `y` / `z`. If it fails, it will be 0. 
  */
  public fun try_mul_div_up(x: u256, y: u256, z: u256): (bool, u256) {
    if (z == 0) return (false, 0);
    let (pred, _) = try_mul(x, y);
    if (!pred) return (false, 0);

    (true, mul_div_up(x, y, z))
  }

  /*
  * @notice It tries to perform `x` % `y`. 
  *
  * @dev Checks for zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u128. The result of `x` % `y`. If it fails, it will be 0. 
  */
  public fun try_mod(x: u256, y: u256): (bool, u256) {
    if (y == 0) (false, 0) else (true, x % y)
  }

  // === These functions will throw on overflow/underflow/zero division ===  

  /*
  * @notice It performs `x` + `y`. 
  *
  * @dev It will throw on overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u64. The result of `x` + `y`. 
  */
  public fun add(x: u256, y: u256): u256 {
    x + y
  }

  /*
  * @notice It performs `x` - `y`. 
  *
  * @dev It will throw on underflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u64. The result of `x` - `y`. 
  */
  public fun sub(x: u256, y: u256): u256 {
    x - y
  }

  /*
  * @notice It performs `x` * `y`. 
  *
  * @dev It will throw on overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u256. The result of `x` * `y`. 
  */
  public fun mul(x: u256, y: u256): u256 {
    x * y
  }

  /*
  * @notice It performs `x` / `y` rounding down. 
  *
  * @dev It will throw on zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u256. The result of `x` / `y`. 
  */  
  public fun div_down(x: u256, y: u256): u256 {
    x / y
  }

  /*
  * @notice It performs `x` / `y` rounding up. 
  *
  * @dev It will throw on zero division. 
  * @dev It does not overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u256. The result of `x` / `y`. 
  */  
  public fun div_up(x: u256, y: u256): u256 {
    if (x == 0) 0 else 1 + (x - 1) / y
  }  

  /*
  * @notice It performs `x` * `y` / `z` rounding down. 
  *
  * @dev It will throw on zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand.  
  * @param z The divisor.
  * @return u256. The result of `x` * `y` / `z`. 
  */
  public fun mul_div_down(x: u256, y: u256, z: u256): u256 {
    x * y / z
  }

  /*
  * @notice It performs `x` * `y` / `z` rounding up. 
  *
  * @dev It will throw on zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @param z The divisor.  
  * @return u256. The result of `x` * `y` / `z`. 
  */
  public fun mul_div_up(x: u256, y: u256, z: u256): u256 {
    let r = mul_div_down(x, y, z);
    r + if ((x * y) % z > 0) 1 else 0
  }

  /*
  * @notice It returns the lowest number. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u256. The lowest number. 
  */
  public fun min(x: u256, y: u256): u256 {
    if (x < y) x else y
  }

  /*
  * @notice It returns the largest number. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u256. The largest number. 
  */
  public fun max(x: u256, y: u256): u256 {
    if (x >= y) x else y
  }  

  /*
  * @notice Clamps `x` between the range of [lower, upper].
  *
  * @param x The operand. 
  * @param lower The lower bound of the range. 
  * @param upper The upper bound of the range.   
  * @return u256. The clamped x. 
  */
  public fun clamp(x: u256, lower: u256, upper: u256): u256 {
    min(upper, max(lower, x))
  }

  /*
  * @notice Performs |x - y|.
  *
  * @param x The first operand. 
  * @param y The second operand.  
  * @return u256. The difference. 
  */
  public fun diff(x: u256, y: u256): u256 {
    if (x > y) {
      x - y
    } else {
      y - x
    }
  }

  /*
  * @notice Performs n^e.
  *
  * @param n The base. 
  * @param e The exponent.  
  * @return u256. The result of n^e. 
  */
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

  /*
  * @notice Adds all xs in a vector.
  *
  * @param nums A vector of numbers.  
  * @return u256. The sum. 
  */
  public fun sum(nums: vector<u256>): u256 {
    let len = vector::length(&nums);
    let i = 0;
    let sum = 0;
    
    while (i < len){
      sum = sum + *vector::borrow(&nums, i);
      i = i + 1;
    };
    
    sum
  }

  /*
  * @notice It returns the average between two numbers (`x` + `y`) / 2.
  *
  * @dev It does not overflow.
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u256. (`x` + `y`) / 2. 
  */
  public fun average(x: u256, y: u256): u256 {
    (x & y) + (x ^ y) / 2
  }



  /*
  * @notice Calculates the average of the vector of numbers sum of vector/length of vector.
  *
  * @param nums A vector of numbers.  
  * @return u256. The average. 
  */
  public fun average_vector(nums: vector<u256>): u256{
    let len = vector::length(&nums);

    if (len == 0) return 0;

    let sum = sum(nums);
    
    sum / (len as u256)
  }
   
  /*
  * @notice Returns the square root of a number. If the number is not a perfect square, the x is rounded down.
  *
  * @dev Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
  *
  * @param x The operand.  
  * @return u256. The square root of x rounding down. 
  */ 
  public fun sqrt_down(x: u256): u256 {
    if (x == 0) return 0;

    let result = 1 << ((log2_down(x) >> 1) as u8);

    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;

    min(result, x / result)
  }

  /*
  * @notice Returns the square root of `x` number. If the number is not a perfect square, the `x` is rounded up.
  *
  * @dev Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
  *
  * @param x The operand.  
  * @return u256. The square root of x rounding up. 
  */ 
  public fun sqrt_up(x: u256): u256 {
    let r = sqrt_down(x);
    r + if (r * r < x) 1 else 0
  }

  /*
  * @notice Returns the log2(x) rounding down.
  *
  * @param x The operand.  
  * @return u256. Log2(x). 
  */ 
  public fun log2_down(x: u256): u8 {
    let result = 0;
    if (x >> 128 > 0) {
      x = x >> 128;
      result = result + 128;
    };
        
    if (x >> 64 > 0) {
      x = x >> 64;
      result = result + 64;
    };
        
    if (x >> 32 > 0) {
      x = x >> 32;
      result = result + 32;
    };
        
    if (x >> 16 > 0) {
      x = x >> 16;
      result = result + 16;
    };
        
    if (x >> 8 > 0) {
      x = x >> 8;
      result = result + 8;
    };
        
    if (x >> 4 > 0) {
      x = x >> 4;
      result = result + 4;
    };
        
    if (x >> 2 > 0) {
      x = x >> 2;
      result = result + 2;
    };
        
    if (x >> 1 > 0) 
      result = result + 1;

    result
  }

  /*
  * @notice Returns the log2(x) rounding up.
  *
  * @param x The operand.  
  * @return u256. Log2(x). 
  */ 
  public fun log2_up(x: u256): u16 {
    let r = log2_down(x);
    (r as u16) + if (1 << (r as u8) < x) 1 else 0
  } 

  /*
  * @notice Returns the log10(x) rounding down.
  *
  * @param x The operand.  
  * @return u256. Log10(x). 
  */ 
  public fun log10_down(x: u256): u8 {
    let result = 0;

    if (x >= 10000000000000000000000000000000000000000000000000000000000000000) {
      x = x / 10000000000000000000000000000000000000000000000000000000000000000;
      result = result + 64;
    };

    if (x >= 100000000000000000000000000000000) {
      x = x / 100000000000000000000000000000000;
      result = result + 32;
    };    
        
    if (x >= 10000000000000000) {
      x = x / 10000000000000000;
      result = result + 16;
    };
        
    if (x >= 100000000) {
      x = x / 100000000;
      result = result + 8;
    };
        
    if (x >= 10000) {
      x = x / 10000;
      result = result + 4;
    };
        
    if (x >= 100) {
      x = x / 100;
      result = result + 2;
    };
        
    if (x >= 10) 
      result = result + 1;

    result
  }

  /*
  * @notice Returns the log10(x) rounding up.
  *
  * @param x The operand.  
  * @return u256. Log10(x). 
  */ 
  public fun log10_up(x: u256): u8 {
    let r = log10_down(x);
    r + if (pow(10, (r as u256)) < x) 1 else 0
  }

  /*
  * @notice Returns the log256(x) rounding down.
  *
  * @param x The operand.  
  * @return u256. Log256(x). 
  */ 
  public fun log256_down(x: u256): u8 {
    let result = 0;

    if (x >> 128 > 0) {
      x = x >> 128;
      result = result + 16;
    };

    if (x >> 64 > 0) {
      x = x >> 64;
      result = result + 8;
    };

    if (x >> 32 > 0) {
      x = x >> 32;
      result = result + 4;
    };

    if (x >> 16 > 0) {
      x = x >> 16;
      result = result + 2;
    };    

    if (x >> 8 > 0)
      result = result + 1;

    result
  }

  /*
  * @notice Returns the log256(x) rounding up.
  *
  * @param x The operand.  
  * @return u256. Log256(x). 
  */ 
  public fun log256_up(x: u256): u8 {
    let r = log256_down(x);
    r + if (1 << ((r << 3)) < x) 1 else 0
  }
}