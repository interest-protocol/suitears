/*
* @title Fixed Point 64
*
* @notice A library to perform math operations over an unsigned integer with 64-bit precision.
*
* @dev Any operation that results in a number larger than the maximum unsigned 128 bit, will be considered an overflow and throw.  
* @dev All credits to Aptos - https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/fixed_point64.move
*/
module suitears::fixed_point64 {  
  // === Imports ===

  use suitears::math128;
  use suitears::math256;

  // === Constants ===

  // @dev Natural log 2 in 32-bit fixed point. ln(2) in fixed 64 representation. 
  const LN2: u256 = 12786308645202655660; 
  
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
  // @dev Abort code on overflow.
  const EOverflowExp: u64 = 5;

  // === Structs ===

  // @dev A type guard to identify a FixedPoint64.
  struct FixedPoint64 has copy, drop, store { value: u128 }

  // === Public-View Functions ===

  /*
  * @notice It returns the raw u128 value. 
  *
  * @param self A FixedPoint64.
  * @return u128. The raw u128 value.
  */
  public fun value(self: FixedPoint64): u128 {
    self.value
  }

  // === Convert Functions ===

  /*
  * @notice Creates a FixedPoint64 from a u128 number. 
  * 
  * @dev It scales the number.
  * @param value A u128 number 
  * @return FixedPoint64. A FixedPoint64 calculated by right shifting - `value` << 64.
  *
  * aborts-if
  * - The left-shifted `value` is larger than `MAX_U128`. 
  */
  public fun from(value: u128): FixedPoint64 {
    let scaled_value = (value as u256) << 64;
    assert!(scaled_value <= MAX_U128, EOutOfRange);
    FixedPoint64 {
      value: (scaled_value as u128)
    }
  }

  /*
  * @notice Creates a FixedPoint64 from a u128 `value`.  
  *
  * @dev It does not scale the `value`.
  * @param value A u128 number 
  * @return FixedPoint64. It wraps the u128.
  */
  public fun from_raw_value(value: u128): FixedPoint64 {
    FixedPoint64 { value }
  }

  /*
  * @notice Creates a FixedPoint64 from a rational number specified by a `numerator` and `denominator`.  
  *
  * @dev 0.0125 will round down to 0.012 instead of up to 0.013.
  * @param numerator The numerator of the rational number. 
  * @param denominator The denominator of the rational number. 
  * @return FixedPoint64. A FixedPoint64 from (`numerator` << 64) / `denominator`
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
  * @notice Converts a FixedPoint64 into a u128 number to the closest integer.  
  *
  * @param self A FixedPoint64. 
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
  * @notice Converts a FixedPoint64 into a u128 number rounding down.  
  *
  * @param self A FixedPoint64. 
  * @return u128.
  */
  public fun to_u128_down(self: FixedPoint64): u128 {
    self.value >> 64
  }

  /*
  * @notice Converts a FixedPoint64 into a u128 number rounding up.  
  *
  * @param self A FixedPoint64. 
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
  * @notice Checks if `self` is zero.  
  *
  * @param self A FixedPoint64. 
  * @return bool. If the `self.value` is zero.
  */
  public fun is_zero(self: FixedPoint64): bool {
    self.value == 0
  }   

  /*
  * @notice Checks if `x` is equal to `y`. 
  * 
  * @param x A FixedPoint64. 
  * @param y A FixedPoint64.   
  * @return bool. If the values are equal. 
  */
  public fun eq(x: FixedPoint64, y: FixedPoint64): bool {
    x.value == y.value
  } 

  /*
  * @notice Checks if `x` is smaller than `y`. 
  * 
  * @param x A FixedPoint64. 
  * @param y A FixedPoint64.   
  * @return bool. If `x` is smaller than `y`.
  */
  public fun lt(x: FixedPoint64, y: FixedPoint64): bool {
    x.value < y.value
  }

  /*
  * @notice Checks if `x` is bigger than `y`.  
  *
  * @param x A FixedPoint64. 
  * @param y A FixedPoint64.   
  * @return bool. If `x` is bigger than `y`.
  */
  public fun gt(x: FixedPoint64, y: FixedPoint64): bool {
    x.value > y.value
  }  

 /*
  * @notice Checks if `x` is smaller or equal to `y`.  
  *
  * @param x A FixedPoint64. 
  * @param y A FixedPoint64.   
  * @return bool. If `x` is smaller or equal to `y`.
  */
  public fun lte(x: FixedPoint64, y: FixedPoint64): bool {
    x.value <= y.value
  }

  /*
  * @notice Checks if `x` is bigger or equal to `y`. 
  * 
  * @param x A FixedPoint64. 
  * @param y A FixedPoint64.   
  * @return bool. If `x` is bigger or equal to `y`.
  */
  public fun gte(x: FixedPoint64, y: FixedPoint64): bool {
    x.value >= y.value
  } 

  /*
  * @notice It returns the larger of the two arguments. 
  *    
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The larger argument. 
  */
  public fun max(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    if (x.value > y.value) x else y
  }

  /*
  * @notice It returns the smaller of the two arguments. 
  *   
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The smaller argument. 
  */
  public fun min(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    if (x.value < y.value) x else y
  }          

  // === Math Operations ===

  /*
  * @notice It returns `x` - `y`.     
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The result of `x` - `y`. 
  *
  * @aborts-if 
  *   - `y` > `x`
  */
  public fun sub(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    let x_raw = x.value;
    let y_raw = y.value;
    assert!(x_raw >= y_raw, ENegativeResult);
    FixedPoint64 {
      value: x_raw - y_raw
    }
  }

  /*
  * @notice It returns `x` + `y`.  
  *   
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The result of `x` + `y`. 
  *
  * @aborts-if 
  *   - `y` + `x` >= `MAX_U128`
  */
  public fun add(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    let x_raw = x.value;
    let y_raw = y.value;
    let result = (x_raw as u256) + (y_raw as u256);
    assert!(result <= MAX_U128, EOutOfRange);
    FixedPoint64 {
      value: (result as u128)
    }
  }

  /*
  * @notice It returns `x` * `y`.    
  *
  * @dev Use {mul_128} if you think the values can overflow.
  * 
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The result of `x` * `y`. 
  *
  * @aborts-if 
  *   - aborts if inner values overflow
  */
  public fun mul(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    FixedPoint64 {
      value: ((((x.value as u256) * (y.value as u256)) >> 64) as u128)
    }
  }

  /*
  * @notice It returns `x` / `y`.    
  * 
  * @param x The first operand. 
  * @param y The second operand. 
  * @return FixedPoint64. The result of `x` / `y`. 
  *
  * @aborts-if 
  *   - aborts if `y` is zero.
  */
  public fun div(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
    assert!(y.value != 0, EZeroDivision);
    FixedPoint64 {
      value: ( math256::div_down((x.value as u256) << 64, (y.value as u256)) as u128)
    }
  } 

  /*
  * @notice Specialized function for `x` * `y` / `z` that omits intermediate shifting.     
  *
  * @param x The first operand. 
  * @param y The second operand. 
  * @param z The third operand.   
  * @return FixedPoint64. The result of `x` * `y` / `z`. 
  *
  * @aborts-if 
  *   - aborts z is zero.
  */
  public fun mul_div(x: FixedPoint64, y: FixedPoint64, z: FixedPoint64): FixedPoint64 {
    assert!(z.value != 0, EZeroDivision);
    FixedPoint64 {
      value: math128::mul_div_down(x.value, y.value, z.value)
    }
  }     

  /*
  * @notice It returns `x` * `y`.   
  * @notice It multiplies a u128 number with a FixedPoint64.
  *
  * @dev It truncates the fractional part of the product. E.g. - 9 * 0.333 = 2.  
  *
  * @param x The first operand, a u128 number. . 
  * @param y The second operand, a FixedPoint64. 
  * @return u128. The result of `x` * `y` without the 64-bit precision. 
  *
  * @aborts-if 
  *   - if the result is larger or equal to `MAX_U128`.
  */
  public fun mul_u128(x: u128, y: FixedPoint64): u128 {
    let unscaled_product = (x as u256) * (y.value as u256);
    let product = unscaled_product >> 64;
    assert!(MAX_U128 >= product, EMultiplicationOverflow);
    (product as u128)
  }

  /*
  * @notice It returns `numerator` / `denominator` rounded down.   
  * @notice It divides a FixedPoint64 by a u128 number.
  *
  * @param numerator The first operand, a u128 number. 
  * @param denominator The second operand, a FixedPoint64. 
  * @return u128. The result of `numerator` / `denominator` without the 64-bit precision. 
  *
  * @aborts-if 
  *   - if the result is larger or equal to `MAX_U128`.
  *   - if the `denominator` is zero.   
  */
  public fun div_down_u128(numerator: u128, denominator: FixedPoint64): u128 {
    assert!(denominator.value != 0, EZeroDivision);
    let scaled_value = (numerator as u256) << 64;
    let quotient = math256::div_down( scaled_value, (denominator.value as u256));
    assert!(quotient <= MAX_U128, EDivisionOverflow);
    (quotient as u128)
  }   

  /*
  * @notice It returns `numerator` / `denominator` rounded up.   
  * @notice It divides a FixedPoint64 by a u128 number.
  *
  * @param numerator The first operand, a u128 number. 
  * @param denominator The second operand, a FixedPoint64. 
  * @return u128. The result of `numerator` / `denominator` without the 64-bit precision. 
  *
  * @aborts-if 
  *   - if the result is larger or equal to `MAX_U128`.
  *   - if the `denominator` is zero. 
  */
  public fun div_up_u128(numerator: u128, denominator: FixedPoint64): u128 {
    assert!(denominator.value != 0, EZeroDivision);
    let scaled_value = (numerator as u256) << 64;
    let quotient = math256::div_up( scaled_value, (denominator.value as u256));
    assert!(quotient <= MAX_U128, EDivisionOverflow);
    (quotient as u128)
  }  

  /*
  * @notice It returns `base` ** `exponent`.   
  *  
  * @param base The base. 
  * @param exponent The exponent. 
  * @return FixedPoint64. The result of `base` ** `exponent`. 
  *
  * @aborts-if 
  *   - aborts if the end result is higher than `MAX_U128`.
  */
  public fun pow(base: FixedPoint64, exponent: u64): FixedPoint64 {
    let raw_value = (base.value as u256);
    FixedPoint64 {
      value: (pow_raw(raw_value, (exponent as u128)) as u128)
    }
  }

  /*
  * @notice Square root of `x`.   
  *  
  * @param x The operand.
  * @return FixedPoint64. The result of the square root. 
  */
  public fun sqrt(x: FixedPoint64): FixedPoint64 {
    let y = x.value;
    let z = (math128::sqrt_down(y) << 32 as u256);
    z = (z + ((y as u256) << 64) / z) >> 1;
    FixedPoint64 {
      value: (z as u128)
    }
  }

  /*
  * @notice Exponent function with a precision of 9 digits.  
  * @notice It performs e^x.    
  *
  * @param x The operand.
  * @return FixedPoint64. The result of e^x. 
  */    
  public fun exp(x: FixedPoint64): FixedPoint64 {
    let raw_value = (x.value as u256);
    FixedPoint64 {
      value: (exp_raw(raw_value) as u128)
    }
  }  

  // === Private Functions ===

  /*
  * @notice Calculates e^x where x and the result are fixed point numbers.  
  *
  * @param x The base. 
  * @return u256. The result of e^x. 
  */  
  fun exp_raw(x: u256): u256 {
    // exp(x / 2^64) = 2^(x / (2^64 * ln(2))) = 2^(floor(x / (2^64 * ln(2))) + frac(x / (2^64 * ln(2))))
    let shift_long = x / LN2;
    assert!(shift_long <= 63, EOverflowExp);
    let shift = (shift_long as u8);
    let remainder = x % LN2;
    // At this point we want to calculate 2^(remainder / ln2) << shift
    // ln2 = 580 * 22045359733108027
    let bigfactor = 22045359733108027;
    let exponent = remainder / bigfactor;
    let x = remainder % bigfactor;
    // 2^(remainder / ln2) = (2^(1/580))^exponent * exp(x / 2^64)
    let roottwo = 18468802611690918839;  // fixed point representation of 2^(1/580)
    // 2^(1/580) = roottwo(1 - eps), so the number we seek is roottwo^exponent (1 - eps * exponent)
    let power = pow_raw(roottwo, (exponent as u128));
    let eps_correction = 219071715585908898;
    power = power - ((power * eps_correction * exponent) >> 128);
    // x is fixed point number smaller than bigfactor/2^64 < 0.0011 so we need only 5 tayler steps
    // to get the 15 digits of precission
    let taylor1 = (power * x) >> (64 - shift);
    let taylor2 = (taylor1 * x) >> 64;
    let taylor3 = (taylor2 * x) >> 64;
    let taylor4 = (taylor3 * x) >> 64;
    let taylor5 = (taylor4 * x) >> 64;
    let taylor6 = (taylor5 * x) >> 64;
    (power << shift) + taylor1 + taylor2 / 2 + taylor3 / 6 + taylor4 / 24 + taylor5 / 120 + taylor6 / 720
  } 

  /*
  * @notice Calculate `x` to the power of `n`, where `x` and the result are fixed point numbers.  
  *
  * @param x The base. 
  * @param n The exponent. 
  * @return u256. The result of x^n. 
  */
  fun pow_raw(x: u256, n: u128): u256 {
    let res: u256 = 1 << 64;
    while (n != 0) {
      if (n & 1 != 0) {
        res = (res * x) >> 64;
      };
      n = n >> 1;
      x = (x * x) >> 64;
    };
    res
  }     
}