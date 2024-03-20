/*
* @title Math128
*
* @notice A set of functions to operate over u128 numbers.
*
* @notice Many functions are implementations of https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol
*
* @dev Beware that some operations throw on overflow and underflows.  
*/
module suitears::math128 {
  // === Imports ===

  use std::vector;

  use suitears::math256;

  // === Constants ===
  
  // @dev The maximum u128 number.
  const MAX_U128: u256 = 340282366920938463463374607431768211455;

  // === Try Functions do not throw ===  

  /*
  * @notice It tries to perform `x` + `y`. 
  *
  * @dev Checks for overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u128. The result of `x` + `y`. If it fails, it will be 0. 
  */
  public fun try_add(x: u128, y: u128): (bool, u128) {
    let c = (x as u256) + (y as u256);
    if (c > MAX_U128) (false, 0) else (true, (c as u128))
  }

  /*
  * @notice It tries to perform `x` - `y`. 
  *
  * @dev Checks for underflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u128. The result of `x` - `y`. If it fails, it will be 0. 
  */
  public fun try_sub(x: u128, y: u128): (bool, u128) {
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
  * @return u128. The result of `x` * `y`. If it fails, it will be 0. 
  */
  public fun try_mul(x: u128, y: u128): (bool, u128) {
    let (pred, c) = math256::try_mul((x as u256), (y as u256));
    if (!pred || c > MAX_U128) (false, 0) else (true, (c as u128))
  }

  /*
  * @notice It tries to perform `x` / `y rounding down. 
  *
  * @dev Checks for zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful.
  * @return u128. The result of x / y. If it fails, it will be 0. 
  */
  public fun try_div_down(x: u128, y: u128): (bool, u128) {
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
  * @return u128. The result of `x` / `y`. If it fails, it will be 0. 
  */
  public fun try_div_up(x: u128, y: u128): (bool, u128) {
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
  * @return u128. The result of `x` * `y` / `z`. If it fails, it will be 0. 
  */
  public fun try_mul_div_down(x: u128, y: u128, z: u128): (bool, u128) {
    let (pred, r) = math256::try_mul_div_down((x as u256), (y as u256), (z as u256));
    if (!pred || r > MAX_U128) (false, 0) else (true, (r as u128))
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
  * @return u128. The result of `x` * `y` / `z`. If it fails, it will be 0. 
  */
  public fun try_mul_div_up(x: u128, y: u128, z: u128): (bool, u128) {
    let (pred, r) = math256::try_mul_div_up((x as u256), (y as u256), (z as u256));
    if (!pred || r > MAX_U128) (false, 0) else (true, (r as u128))
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
  public fun try_mod(x: u128, y: u128): (bool, u128) {
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
  public fun add(x: u128, y: u128): u128 {
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
  public fun sub(x: u128, y: u128): u128 {
    x - y
  }

  /*
  * @notice It performs `x` * `y`. 
  *
  * @dev It will throw on overflow. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u128. The result of `x` * `y`. 
  */
  public fun mul(x: u128, y: u128): u128 {
    x * y
  }

  /*
  * @notice It performs `x` / `y` rounding down. 
  *
  * @dev It will throw on zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u128. The result of `x` / `y`. 
  */   
  public fun div_down(x: u128, y: u128): u128 {
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
  * @return u128. The result of `x` / `y`. 
  */  
  public fun div_up(a: u128, b: u128): u128 {
    // (a + b - 1) / b can overflow on addition, so we distribute.
    if (a == 0) 0 else 1 + (a - 1) / b
  }  

  /*
  * @notice It performs `x` * `y` / `z` rounding down. 
  *
  * @dev It will throw on zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand.  
  * @param z The divisor.
  * @return u128. The result of `x` * `y` / `z`. 
  */
  public fun mul_div_down(x: u128, y: u128, z: u128): u128 {
    (math256::mul_div_down((x as u256), (y as u256), (z as u256)) as u128)
  }

  /*
  * @notice It performs `x` * `y` / `z` rounding up. 
  *
  * @dev It will throw on zero division. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @param z The divisor.  
  * @return u128. The result of `x` * `y` / `z`. 
  */
  public fun mul_div_up(x: u128, y: u128, z: u128): u128 {
    (math256::mul_div_up((x as u256), (y as u256), (z as u256)) as u128)
  }

  /*
  * @notice It returns the lowest number. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u128. The lowest number. 
  */
  public fun min(a: u128, b: u128): u128 {
    if (a < b) a else b
  }

  /*
  * @notice It returns the largest number. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u128. The largest number. 
  */
  public fun max(x: u128, y: u128): u128 {
    if (x >= y) x else y
  }  

  /*
  * @notice Clamps `x` between the range of [lower, upper].
  *
  * @param x The operand. 
  * @param lower The lower bound of the range. 
  * @param upper The upper bound of the range.   
  * @return u128. The clamped x. 
  */
  public fun clamp(x: u128, lower: u128, upper: u128): u128 {
    min(upper, max(lower, x))
  }  

  /*
  * @notice Performs |x - y|.
  *
  * @param x The first operand. 
  * @param y The second operand.  
  * @return u128. The difference. 
  */
  public fun diff(x: u128, y: u128): u128 {
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
  * @return u128. The result of n^e. 
  */
  public fun pow(n: u128, e: u128): u128 {
    (math256::pow((n as u256), (e as u256)) as u128)
  }

   /*
  * @notice Adds all x in `nums` in a vector.
  *
  * @param nums A vector of numbers.  
  * @return u256. The sum. 
  */
  public fun sum(nums: vector<u128>): u128 {
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
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u128. (`x` + `y`) / 2. 
  */
  public fun average(a: u128, b: u128): u128 {
    // (a + b) / 2 can overflow.
    (a & b) + (a ^ b) / 2
  }

  /*
  * @notice Calculates the average of the vector of numbers sum of vector/length of vector.
  *
  * @param nums A vector of numbers.  
  * @return u128. The average. 
  */
  public fun average_vector(nums: vector<u128>): u128{
    let len = vector::length(&nums);

    if (len == 0) return 0;

    let sum = sum(nums);
    
    sum / (len as u128)
  }
  
  /*
  * @notice Returns the square root of `x` number. If the number is not a perfect square, the x is rounded down.
  *
  * @dev Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
  *
  * @param x The operand.  
  * @return u128. The square root of x rounding down. 
  */   
  public fun sqrt_down(x: u128): u128 {
    (math256::sqrt_down((x as u256)) as u128)
  }

   /*
  * @notice Returns the square root of `x` number. If the number is not a perfect square, the `x` is rounded up.
  *
  * @dev Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
  *
  * @param x The operand.  
  * @return u128. The square root of x rounding up. 
  */ 
  public fun sqrt_up(x: u128): u128 {
    (math256::sqrt_up((x as u256)) as u128)
  }

  /*
  * @notice Returns the log2(x) rounding down.
  *
  * @param x The operand.  
  * @return u8. Log2(x). 
  */ 
  public fun log2_down(x: u128): u8 {
   math256::log2_down((x as u256))
  }

  /*
  * @notice Returns the log2(x) rounding up.
  *
  * @param x The operand.  
  * @return u16. Log2(x). 
  */ 
  public fun log2_up(x: u128): u16 {
   math256::log2_up((x as u256))
  }

  /*
  * @notice Returns the log10(x) rounding down.
  *
  * @param x The operand.  
  * @return u8. Log10(x). 
  */
  public fun log10_down(x: u128): u8 {
    math256::log10_down((x as u256))
  }

  /*
  * @notice Returns the log10(x) rounding up.
  *
  * @param x The operand.  
  * @return u8. Log10(x). 
  */
  public fun log10_up(x: u128): u8 {
    math256::log10_up((x as u256))
  }

  /*
  * @notice Returns the log256(x) rounding down.
  *
  * @param x The operand.  
  * @return u8. Log256(x). 
  */ 
  public fun log256_down(x: u128): u8 {
    math256::log256_down((x as u256))
  }

  /*
  * @notice Returns the log256(x) rounding up.
  *
  * @param x The operand.  
  * @return u8. Log256(x). 
  */ 
  public fun log256_up(x: u128): u8 {
    math256::log256_up((x as u256))
  }  
}
