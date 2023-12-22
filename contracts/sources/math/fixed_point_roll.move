/*
* @title Fixed Point Roll
*
* @notice A set of functions to operate over u64 numbers with 1e9 precision.
*
* @dev It has the same precision as Sui's native token to facilitate operations. 
*/
module suitears::fixed_point_roll {
  // === Imports ===  

  use suitears::math64;

  // === Constants ===

  // @dev One roll represents the Sui's native token decimal scalar. A value of 1e9.
  const ROLL: u64 = 1_000_000_000; 

  // === Constant Function ===  

  /*
  * @notice It returns 1 ROLL. 
  *
  * @return u64. 1e9. 
  */
  public fun roll(): u64 {
    ROLL
  }

  // === Try Functions ===  

  /*
  * @notice It tries to `x` * `y` / `ROLL` rounding down.
  *
  * @dev It returns zero instead of throwing an overflow error. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return bool. If the operation was successful or not.
  * @return u64. The result of `x` * `y` / `ROLL`. 
  */
  public fun try_mul_down(x: u64, y: u64): (bool, u64) {
    math64::try_mul_div_down(x, y, ROLL)
  }

  /*
  * @notice It tries to `x` * `y` / `ROLL` rounding up.
  *
  * @dev It returns zero instead of throwing an overflow error. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @param bool. If the operation was successful or not.
  * @return u64. The result of `x` * `y` / `ROLL`. 
  */
  public fun try_mul_up(x: u64, y: u64): (bool, u64) {
    math64::try_mul_div_up(x, y, ROLL)
  }

  /*
  * @notice It tries to `x` * `ROLL` / `y` rounding down.
  *
  * @dev It will return 0 if `y` is zero.
  * @dev It returns zero instead of throwing an overflow error. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @param bool. If the operation was successful or not.
  * @return u64. The result of `x` * `ROLL` / `y`. 
  */
  public fun try_div_down(x: u64, y: u64): (bool, u64) {
    math64::try_mul_div_down(x, ROLL, y)
  }

  /*
  * @notice It tries to `x` * `ROLL` / `y` rounding up.
  *
  * @dev It will return 0 if `y` is zero.
  * @dev It returns zero instead of throwing an overflow error. 
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @param bool. If the operation was successful or not.
  * @return u64. The result of `x` * `ROLL` / `y`. 
  */
  public fun try_div_up(x: u64, y: u64): (bool, u64) {
    math64::try_mul_div_up(x, ROLL, y)
  }

  // === These operations will throw on overflow/underflow/zero division ===  

  /*
  * @notice `x` * `y` / `ROLL` rounding down.
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u64. The result of `x` * `y` / `ROLL`. 
  */
  public fun mul_down(x: u64, y: u64): u64 {
    math64::mul_div_down(x, y, ROLL)
  }

  /*
  * @notice `x` * `y` / `ROLL` rounding up.
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u64. The result of `x` * `y` / `ROLL`. 
  */
  public fun mul_up(x: u64, y: u64): u64 {
    math64::mul_div_up(x, y, ROLL)
  }

  /*
  * @notice `x` * `ROLL` / `y` rounding down.
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u64. The result of `x` * `ROLL` / `y`. 
  */
  public fun div_down(x: u64, y: u64): u64 {
    math64::mul_div_down(x, ROLL, y)
  }

  /*
  * @notice `x` * `ROLL` / `y` rounding up.
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return u64. The result of `x` * `ROLL` / `y`. 
  */
  public fun div_up(x: u64, y: u64): u64 {
    math64::mul_div_up(x, ROLL, y)
  }

  /*
  * @notice It converts `x` precision to a `ROLL`, a number with a precision of 1e9.
  *
  * @param x The value to be converted. 
  * @param decimal_factor The current decimal scalar of the x. 
  * @return u64. The result of `x` * `ROLL` / `decimal_factor`. 
  */
  public fun to_roll(x: u64, decimal_factor: u64): u64 {
    math64::mul_div_down(x, ROLL, (decimal_factor as u64))
  }
}