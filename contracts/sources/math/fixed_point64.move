/*
* @title Fixed Point 64: A library to perform math operations over an unsigned integer with 64-bit precision.
* @dev Any operation that results in a number larger than the maximum unsigned 128 bit, will be considered an overflow and throw.  
* @dev All credits to Aptos - https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/fixed_point64.move
*/
module suitears::fixed_point64 {  
  // === Imports ===

  use suitears::math256;

  // === Constants ===
    
  // @dev Maximum Unsigned 128 Bit number
  const MAX_U128: u256 =  340282366920938463463374607431768211455;

  // === Errors ===

  // @dev It is thrown if an operation results in a negative number. 
  const ENegativeResult: u64 = 0;
  // @dev It is thrown if an operation results in a value outside of 2^-64 .. 2^64-1.
  const EOutOfRange: u64 = 1;
  // @dev It is thrown if a multiplication operation results in a number larger or equal to `MAX_U128`. 
  const EMultiplicationOverflow: u64 = 2;
  // @dev It is thrown if one tries to divide by zero. 
  const EZeroDivision: u64 = 3;
  // @dev If the result of a division operation results in a number larger or equal to `MAX_U128`.
  const EDivisionOverflow: u64 = 4;

  // === Structs ===

  // @dev A type guard to identify a fixed-point value.
  struct FixedPoint64 has copy, drop, store { value: u128 }

  // === Public-View Functions ===

  /*
  * @notice It returns the raw u128 value. 
  * @param self A fixed-point value.
  * @return u128 The raw u128 value.
  */
  public fun value(self: FixedPoint64): u128 {
    self.value
  }

  // === Convert Functions ===

  /*
  * @notice Creates a fixed-point value from a u128 number.  
  * @dev It scales the number.
  * @param value A u128 number 
  * @return FixedPoint64. A fixed-point value calculated by right shifting (value << 64).
  */
  public fun from(value: u128): FixedPoint64 {
    let scaled_value = (value as u256) << 64;
    assert!(scaled_value <= MAX_U128, EOutOfRange);
    FixedPoint64 {
      value: (value as u128)
    }
  }

  /*
  * @notice Creates a fixed-point value from a u128 number.  
  * @dev It does not scale the number.
  * @param value A u128 number 
  * @return FixedPoint64. It wraps the u128.
  */
  public fun from_raw_value(value: u128): FixedPoint64 {
    FixedPoint64 { value }
  }

  /*
  * @notice Creates a fixed-point value from a rational number specified by a numerator and denominator.  
  * @dev 0.0125 will round down to 0.012 instead of up to 0.013.
  * @param numerator The numerator of the rational number. 
  * @param denominator The denominator of the rational number. 
  * @return FixedPoint64. A fixed-point value from (numerator << 64) / denominator
  *
  * @aborts-if 
  *   - if the denominator is zero
  *   - if the numerator / denominator is zero 
  *   - if the numerator is nonzero and the ratio is not in the range 2^-64 .. 2^64-1
  */
  public fun from_rational(numerator: u128, denominator: u128): FixedPoint64 {
    let scaled_numerator = (numerator as u256) << 64;
    assert!(denominator != 0, EZeroDivision);
    let quotient = scaled_numerator / (denominator as u256);
    assert!(quotient != 0 || numerator == 0, EOutOfRange);
    assert!(quotient <= MAX_U128, EOutOfRange);
    FixedPoint64 { value: (quotient as u128) }
  }

  /*
  * @notice Converts a fixed-point value into a u128 number to the closest integer.  
  * @param self A fixed-point value. 
  * @return u128.
  */
  public fun to_u128(self: FixedPoint64): u128 {
    let floored_num = to_u128_down(self) << 64;
    let boundary = floored_num + ((1 << 64) / 2);
    if (self.value < boundary) {
      floored_num >> 64
    } else {
      to_u128_up(self)
    }
  }   

  /*
  * @notice Converts a fixed-point value into a u128 number rounding down.  
  * @param self A fixed-point value. 
  * @return u128.
  */
  public fun to_u128_down(self: FixedPoint64): u128 {
    self.value >> 64
  }

  /*
  * @notice Converts a fixed-point value into a u128 number rounding up.  
  * @param self A fixed-point value. 
  * @return u128.
  */
  public fun to_u128_up(self: FixedPoint64): u128 {
    let floored_num = to_u128_down(self) << 64;
    if (self.value == floored_num) {
      return floored_num >> 64
    };
    let val = ((floored_num as u256) + (1 << 64));
    (val >> 64 as u128)
  }    

  // === Comparison Functions === 

  /*
  * @notice Checks if self is zero.  
  * @param self A fixed-point value. 
  * @return bool. If the value is zero.
  */
  public fun is_zero(self: FixedPoint64): bool {
    self.value == 0
  }   

  /*
  * @notice Checks if x is equal to y.  
  * @param x A fixed-point value. 
  * @param y A fixed-point value.   
  * @return bool. If the values are equal
  */
  public fun eq(x: FixedPoint64, y: FixedPoint64): bool {
    x.value == y.value
  } 

  /*
  * @notice Checks if x is smaller than y.  
  * @param x A fixed-point value. 
  * @param y A fixed-point value.   
  * @return bool. If x is smaller than y.
  */
  public fun lt(x: FixedPoint64, y: FixedPoint64): bool {
    x.value < y.value
  }

  /*
  * @notice Checks if x is bigger than y.  
  * @param x A fixed-point value. 
  * @param y A fixed-point value.   
  * @return bool. If x is bigger than y.
  */
  public fun gt(x: FixedPoint64, y: FixedPoint64): bool {
    x.value > y.value
  }  

 /*
  * @notice Checks if x is smaller or equal to y.  
  * @param x A fixed-point value. 
  * @param y A fixed-point value.   
  * @return bool. If x is smaller or equal to y.
  */
  public fun lte(x: FixedPoint64, y: FixedPoint64): bool {
    x.value <= y.value
  }

  /*
  * @notice Checks if x is bigger or equal to y.  
  * @param x A fixed-point value. 
  * @param y A fixed-point value.   
  * @return bool. If x is bigger or equal to y.
  */
  public fun gte(x: FixedPoint64, y: FixedPoint64): bool {
    x.value >= y.value
  } 

  /*
  * @notice It returns the larger of the two arguments.     
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The larger argument. 
  */
  public fun max(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    if (x.value > y.value) x else y
  }

  /*
  * @notice It returns the smaller of the two arguments.     
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The smaller argument. 
  */
  public fun min(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    if (x.value < y.value) x else y
  }          

  // === Addition, Subtraction, Multiplication and Division ===

  /*
  * @notice It returns x - y.     
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The result of x - y. 
  *
  * @aborts-if 
  *   - y > x
  */
  public fun sub(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    let x_raw = x.value;
    let y_raw = y.value;
    assert!(x_raw >= y_raw, ENegativeResult);
    from_raw_value(x_raw - y_raw)
  }

  /*
  * @notice It returns x + y.     
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The result of x + y. 
  *
  * @aborts-if 
  *   - y + x >= `MAX_U128`
  */
  public fun add(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    let x_raw = x.value;
    let y_raw = y.value;
    let result = (x_raw as u256) + (y_raw as u256);
    assert!(result <= MAX_U128, EOutOfRange);
    from_raw_value((result as u128))
  }

  /*
  * @notice It returns x * y.   
  * @notice It multiplies a u128 number with a fixed-point value.
  * @dev It truncates the fractional part of the product. E.g. - 9 * 0.333 = 2.  
  * @param x The first operand, a u128 number. . 
  * @param y The second operand, a fixed-point value. 
  * @return u128. The result of x * y without the 64 bit precision. 
  *
  * @aborts-if 
  *   - if the result is larger or equal than `MAX_U128`.
  */
  public fun mul_u128(x: u128, y: FixedPoint64): u128 {
    let unscaled_product = (x as u256) * (y.value as u256);
    let product = unscaled_product >> 64;
    assert!(MAX_U128 >= product, EMultiplicationOverflow);
    (product as u128)
  }

  /*
  * @notice It returns numerator/denominator rounded up.   
  * @notice It divides a u128 number by a fixed-point value.
  * @param numerator The first operand, a u128 number. 
  * @param denominator The second operand, a fixed-point value. 
  * @return u128. The result of numerator/denominator without the 64-bit precision. 
  *
  * @aborts-if 
  *   - if the result is larger or equal to `MAX_U128`.
  */
  public fun div_up_u128(numerator: u128, denominator: FixedPoint64): u128 {
    assert!(denominator.value != 0, EZeroDivision);
    let scaled_value = (numerator as u256) << 64;
    let quotient = math256::div_up( scaled_value, (denominator.value as u256));
    assert!(quotient <= MAX_U128, EDivisionOverflow);
    (quotient as u128)
  }

  /*
  * @notice It returns numerator/denominator rounded down.   
  * @notice It divides a fixed-point value by a u128 number.
  * @param numerator The first operand, a u128 number. 
  * @param denominator The second operand, a fixed-point value. 
  * @return u128. The result of numerator/denominator without the 64-bit precision. 
  *
  * @aborts-if 
  *   - if the result is larger or equal to `MAX_U128`.
  */
  public fun div_down_u128(numerator: u128, denominator: FixedPoint64): u128 {
    assert!(denominator.value != 0, EZeroDivision);
    let scaled_value = (numerator as u256) << 64;
    let quotient = math256::div_down( scaled_value, (denominator.value as u256));
    assert!(quotient <= MAX_U128, EDivisionOverflow);
    (quotient as u128)
  }    
}