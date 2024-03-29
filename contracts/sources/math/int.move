/*
* @title Int 
*
* @notice A library to convert unsigned integers to signed integers using two's complement. It contains basic arithmetic operations for signed integers. 
*
* @dev It is inspired by Movemate i64 https://github.com/pentagonxyz/movemate/blob/main/sui/sources/i64.move 
* @dev Uses arithmetic shr and shl for negative numbers 
*/
module suitears::int {
  // === Imports ===

  use suitears::math256;  

  // === Friend modules ===

  friend suitears::math64;

  // === Constants ===
  
  // @dev Maximum i256 as u256. We need one bit for the sign. 0 positive / 1 negative.  
  const MAX_I256_AS_U256: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
  
  // @dev Maximum u256 number.
  const MAX_U256: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
  
  // @dev A mask to check if a number is positive or negative. It has the MSB set to 1. 
  const U256_WITH_FIRST_BIT_SET: u256 = 1 << 255;

  // Compare Results

  const EQUAL: u8 = 0;

  const LESS_THAN: u8 = 1;

  const GREATER_THAN: u8 = 2;

  // === Errors ===

  // @dev It occurs if an operation results in a value higher than `MAX_I256_U256`.   
  const EConversionFromU256Overflow: u64 = 0;
  
  // @dev It occurs if a negative Int is converted to an unsigned integer. 
  const EConversionUnderflow: u64 = 1;

  // === Structs ===
  
  // @dev A wrapper to represent signed integers.
  struct Int has copy, drop, store {
    value: u256
  }

  // === Public View Function ===  
  
  /*
  * @notice It returns the inner value inside `self`.
  *
  * @param self The Int struct.  
  * @return u256. The inner value.
  */
  public fun value(self: Int): u256 {
    self.value
  }

  // === Public Create Functions ===   

  /*
  * @notice It creates a zero `Int`.   
  *
  * @return Int. The wrapped value.
  */
  public fun zero(): Int {
    Int { value: 0 }
  }

  /*
  * @notice It creates an `Int` with a value of 1. 
  *  
  * @return Int. The wrapped value.
  */
  public fun one(): Int {
    Int { value: 1 }
  } 

  /*
  * @notice It creates the largest possible `Int`.
  *   
  * @return Int. The wrapped value.
  */
  public fun max(): Int {
    Int { value: MAX_I256_AS_U256 }
  }

  /*
  * @notice It wraps a u8 `value` into an `Int`.  
  *
  * @param value The u8 value to wrap  
  * @return Int. The wrapped `value`.
  */
  public fun from_u8(value: u8): Int {
    Int { value: (value as u256) }
  }

  /*
  * @notice It wraps a u16 `value` into an `Int`. 
  * 
  * @param value The u16 value to wrap  
  * @return Int. The wrapped `value`.
  */
  public fun from_u16(value: u16): Int {
    Int { value: (value as u256) }
  }

  /*
  * @notice It wraps a u32 `value` into an `Int`.  
  *
  * @param value The u32 value to wrap  
  * @return Int. The wrapped `value`.
  */
  public fun from_u32(value: u32): Int {
    Int { value: (value as u256) }
  }

  /*
  * @notice It wraps a u64 `value` into an `Int`.  
  *
  * @param value The u64 value to wrap  
  * @return Int. The wrapped `value`.
  */
  public fun from_u64(value: u64): Int {
    Int { value: (value as u256) }
  }

  /*
  * @notice It wraps a u128 `value` into an `Int`.
  *  
  * @param value The u128 value to wrap  
  * @return Int. The wrapped `value`.
  */
  public fun from_u128(value: u128): Int {
    Int { value: (value as u256) }
  }

  /*
  * @notice It wraps a u256 `value` into an `Int`.  
  *
  * @param value The u256 value to wrap  
  * @return Int. The wrapped `value`.
  *
  * aborts-if 
  *  - if value is larger than `MAX_I256_AS_U256`.  
  */
  public fun from_u256(value: u256): Int {
    assert!(value <= MAX_I256_AS_U256, EConversionFromU256Overflow);
    Int { value: value }
  }

  /*
  * @notice It wraps a u8 `value` into an `Int` and negates it.  
  *
  * @param value The u8 value to wrap  
  * @return Int. The wrapped negative `value`.
  */
  public fun neg_from_u8(value: u8): Int {
    let ret = from_u8(value);
    if (ret.value > 0) *&mut ret.value = MAX_U256 - ret.value + 1;
    ret
  }

  /*
  * @notice It wraps a u16 `value` into an `Int` and negates it.  
  *
  * @param value The u16 value to wrap  
  * @return Int. The wrapped negative `value`.
  */
  public fun neg_from_u16(value: u16): Int {
    let ret = from_u16(value);
    if (ret.value > 0) *&mut ret.value = MAX_U256 - ret.value + 1;
    ret
  }

  /*
  * @notice It wraps a u32 `value` into an `Int` and negates it.  
  *
  * @param value The u32 value to wrap  
  * @return Int. The wrapped negative `value`.
  */
  public fun neg_from_u32(value: u32): Int {
    let ret = from_u32(value);
    if (ret.value > 0) *&mut ret.value = MAX_U256 - ret.value + 1;
    ret
  }

  /*
  * @notice It wraps a u64 `value` into an `Int` and negates it. 
  * 
  * @param value The u64 value to wrap  
  * @return Int. The wrapped negative `value`.
  */
  public fun neg_from_u64(value: u64): Int {
    let ret = from_u64(value);
    if (ret.value > 0) *&mut ret.value = MAX_U256 - ret.value + 1;
    ret
  }

  /*
  * @notice It wraps a u128 `value` into an `Int` and negates it.  
  *
  * @param value The u128 value to wrap  
  * @return Int. The wrapped negative `value`.
  */
  public fun neg_from_u128(value: u128): Int {
    let ret = from_u128(value);
    if (ret.value > 0) *&mut ret.value = MAX_U256 - ret.value + 1;
    ret
  }

  /*
  * @notice It wraps a u256 `value` into an `Int` and negates it.  
  *
  * @param value The u256 value to wrap  
  * @return Int. The wrapped negative `value`.
  */
  public fun neg_from_u256(value: u256): Int {
    let ret = from_u256(value);
    if (ret.value > 0) *&mut ret.value = MAX_U256 - ret.value + 1;
    ret
  }

  /*
  * @notice It unwraps the value inside `self` and casts it to u8.  
  *
  * @param self The Int struct.  
  * @return u8. The inner value cast to u8. 
  *
  * aborts-if 
  *  - `self.value` is negative
  */
  public fun to_u8(self: Int): u8 {
    assert!(is_positive(self), EConversionUnderflow);
    (self.value as u8)
  }

  /*
  * @notice It unwraps the value inside `self` and casts it to u16. 
  * 
  * @param self The Int struct.  
  * @return u16. The inner value cast to u16. 
  *
  * aborts-if 
  *  - `self.value` is negative
  */
  public fun to_u16(self: Int): u16 {
    assert!(is_positive(self), EConversionUnderflow);
    (self.value as u16)
  }

  /*
  * @notice It unwraps the value inside `self` and casts it to u32.  
  *
  * @param self The Int struct.  
  * @return u32. The inner value cast to u32. 
  *
  * aborts-if 
  *  - `self.value` is negative
  */
  public fun to_u32(self: Int): u32 {
    assert!(is_positive(self), EConversionUnderflow);
    (self.value as u32)
  }

  /*
  * @notice It unwraps the value inside `self` and casts it to u64.  
  *
  * @param self The Int struct.  
  * @return u64. The inner value cast to u64. 
  *
  * aborts-if 
  *  - `self.value` is negative
  */
  public fun to_u64(self: Int): u64 {
    assert!(is_positive(self), EConversionUnderflow);
    (self.value as u64)
  }

  /*
  * @notice It unwraps the value inside `self` and casts it to u128.  
  *
  * @param self The Int struct.  
  * @return u128. The inner value cast to u128. 
  *
  * aborts-if 
  *  - `self.value` is negative
  */
  public fun to_u128(self: Int): u128 {
    assert!(is_positive(self), EConversionUnderflow);
    (self.value as u128)
  }

  /*
  * @notice It unwraps the value inside `self` and casts it to u256. 
  * 
  * @param self The Int struct.  
  * @return u256. The inner value cast to u256. 
  *
  * aborts-if 
  *  - `self.value` is negative
  */
  public fun to_u256(self: Int): u256 {
    assert!(is_positive(self), EConversionUnderflow);
    self.value
  }

  /*
  * @notice It unwraps the value inside `self` and truncates it to u8.  
  *
  * @param self The Int struct.  
  * @return u8. The inner value is truncated to u8. 
  */
  public fun truncate_to_u8(self: Int): u8 {
    ((self.value & 0xFF) as u8)
  }

  /*
  * @notice It unwraps the value inside `self` and truncates it to u16.  
  *
  * @param self The Int struct.  
  * @return u16. The inner value is truncated to u16. 
  */
  public fun truncate_to_u16(self: Int): u16 {
    ((self.value & 0xFFFF) as u16)
  }

  /*
  * @notice It unwraps the value inside `self` and truncates it to u32.  
  *
  * @param self The Int struct.  
  * @return u32. The inner value is truncated to u32. 
  */
  public fun truncate_to_u32(self: Int): u32 {
    ((self.value & 0xFFFFFFFF) as u32)
  }

  /*
  * @notice It unwraps the value inside `self` and truncates it to u64.  
  * @param self The Int struct.  
  * @return u64. The inner value is truncated to u64. 
  */
  public fun truncate_to_u64(self: Int): u64 {
    ((self.value & 0xFFFFFFFFFFFFFFFF) as u64)
  }

  /*
  * @notice It unwraps the value inside `self` and truncates it to u128.  
  * @param self The Int struct.  
  * @return u128. The inner value is truncated to u128. 
  */
  public fun truncate_to_u128(self: Int): u128 {
    ((self.value & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) as u128)
  }

  // === Public Utility Functions ===   

  /*
  * @notice It flips the sign of `self`.  
  * @param self The Int struct.  
  * @return Int. The returned Int will have its signed flipped.  
  */
  public fun flip(self: Int): Int {
    if (is_neg(self)) { abs(self) } else { neg_from_u256(self.value) } 
  }

  /*
  * @notice It returns the absolute of an Int.  
  * @param self The Int struct.  
  * @return Int. The absolute.  
  */
  public fun abs(self: Int): Int {
    if (is_neg(self)) from_u256((self.value ^ MAX_U256) + 1) else self
  }

  // === Public Predicate Functions ===   

  /*
  * @notice It checks if `self` is negative.  
  * @param self The Int struct.  
  * @return bool.  
  */
  public fun is_neg(self: Int): bool {
    (self.value & U256_WITH_FIRST_BIT_SET) != 0
  }

  /*
  * @notice It checks if `self` is zero.  
  * @param self The Int struct.  
  * @return bool.  
  */
  public fun is_zero(self: Int): bool {
    self.value == 0
  }

  /*
  * @notice It checks if `self` is positive.  
  * @param self The Int struct.  
  * @return bool.  
  */
  public fun is_positive(self: Int): bool {
    U256_WITH_FIRST_BIT_SET > self.value
  }


  /*
  * @notice It compares `a` and `b`.  
  * @param a An Int struct.  
  * @param b An Int struct.  
  * @return 0. a == b.  
  * @return 1. a < b.  
  * @return 2. a > b.    
  */
  public fun compare(a: Int, b: Int): u8 {
    if (a.value == b.value) return EQUAL;
    if (is_positive(a)) {
      // A is positive
      if (is_positive(b)) {
      // A and B are positive
        return if (a.value > b.value) GREATER_THAN else LESS_THAN
      } else {
      // B is negative
        return GREATER_THAN
      }
    } else {
    // A is negative
      if (is_positive(b)) {
      // A is negative and B is positive
        return LESS_THAN
      } else {
      // A is negative and B is negative
        return if (abs(a).value > abs(b).value) LESS_THAN else GREATER_THAN
      }
    }
  }

  /*
  * @notice It checks if `a` and `b` are equal.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return bool.  
  */
  public fun eq(a: Int, b: Int): bool {
    compare(a, b) == EQUAL
  }

  /*
  * @notice It checks if `a` < `b`.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return bool.  
  */
  public fun lt(a: Int, b: Int): bool {
    compare(a, b) == LESS_THAN
  }

  /*
  * @notice It checks if `a` <= `b`.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return bool.  
  */
  public fun lte(a: Int, b: Int): bool {
    let pred = compare(a, b);
    pred == LESS_THAN || pred == EQUAL
  }

  /*
  * @notice It checks if `a` > `b`.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return bool.  
  */
  public fun gt(a: Int, b: Int): bool {
    compare(a, b) == GREATER_THAN
  }

  /*
  * @notice It checks if `a` >= `b`.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return bool.  
  */
  public fun gte(a: Int, b: Int): bool {
    let pred = compare(a, b);
    pred == GREATER_THAN || pred == EQUAL
  }

  // === Math Operations ===

  /*
  * @notice It performs `a` + `b`.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return Int. The result of `a` + `b`.  
  */
  public fun add(a: Int, b: Int): Int {
    if (is_positive(a)) {
    // A is posiyive
      if (is_positive(b)) {
      // A and B are posistive;
        from_u256(a.value + b.value)
      } else {
      // A is positive but B is negative
        let b_abs = abs(b);
        if (a.value >= b_abs.value) return from_u256(a.value - b_abs.value);
        return neg_from_u256(b_abs.value - a.value)
      }
    } else {
    // A is negative
      if (is_positive(b)) {
      // A is negative and B is positive
        let a_abs = abs(a);
        if (b.value >= a_abs.value) return from_u256(b.value - a_abs.value);
        return neg_from_u256(a_abs.value - b.value)
      } else {
      // A and B are negative
        neg_from_u256(abs(a).value + abs(b).value)
      }
    }
  }

  /*
  * @notice It performs `a` - `b`.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return Int. The result of `a` - `b`.  
  */
  public fun sub(a: Int, b: Int): Int {
    if (is_positive(a)) {
      // A is positive
      if (is_positive(b)) {
      // B is positive
        if (a.value >= b.value) return from_u256(a.value - b.value); // Return positive
          return neg_from_u256(b.value - a.value) // Return negative
      } else {
      // B is negative
        return from_u256(a.value + abs(b).value) // Return positive
      }
    } else {
    // A is negative
      if (is_positive(b)) {
        // B is positive
        return neg_from_u256(abs(a).value + b.value) // Return negative
      } else {
        // B is negative
        let a_abs = abs(a);
        let b_abs = abs(b);
        if (b_abs.value >= a_abs.value) return from_u256(b_abs.value - a_abs.value); // Return positive
        return neg_from_u256(a_abs.value - b_abs.value) // Return negative
      }
    }
  }

  /*
  * @notice It performs `a` * `b`.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return Int. The result of `a` * `b`.  
  */
  public fun mul(a: Int, b: Int): Int {
    if (is_positive(a)) {
      // A is positive
      if (is_positive(b)) {
        // B is positive
        return from_u256(a.value * b.value)// Return positive
      } else {
        // B is negative
        return neg_from_u256(a.value * abs(b).value) // Return negative
      }
    } else {
      // A is negative
      if (is_positive(b)) {
        // B is positive
         return neg_from_u256(abs(a).value * b.value) // Return negative
      } else {
      // B is negative
        return from_u256(abs(a).value * abs(b).value ) // Return positive
      }
    }
  }

  /*
  * @notice It performs `a` / `b` rounding down.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return Int. The result of `a` / `b` rounding down.  
  */
  public fun div_down(a: Int, b: Int): Int {
    if (is_positive(a)) {
      // A is positive
      if (is_positive(b)) {
        // B is positive
        return from_u256(math256::div_down(a.value, b.value)) // Return positive
      } else {
        // B is negative
        return neg_from_u256(math256::div_down(a.value, abs(b).value)) // Return negative
      }
    } else {
      // A is negative
      if (is_positive(b)) {
        // B is positive
        return neg_from_u256(math256::div_down(abs(a).value, b.value)) // Return negative
      } else {
        // B is negative
        return from_u256(math256::div_down(abs(a).value, abs(b).value)) // Return positive
      }
    }    
  }

  /*
  * @notice It performs `a` / `b` rounding up.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return Int. The result of `a` / `b` rounding up.  
  */
  public fun div_up(a: Int, b: Int): Int {
    if (is_positive(a)) {
      // A is positive
      if (is_positive(b)) {
        // B is positive
        return from_u256(math256::div_up(a.value, b.value)) // Return positive
      } else {
        // B is negative
        return neg_from_u256(math256::div_up(a.value, abs(b).value)) // Return negative
      }
    } else {
      // A is negative
      if (is_positive(b)) {
        // B is positive
        return neg_from_u256(math256::div_up(abs(a).value, b.value)) // Return negative
      } else {
        // B is negative
        return from_u256(math256::div_up(abs(a).value, abs(b).value)) // Return positive
      }
    }    
  }  

  /*
  * @notice It performs `a` % `b`.  
  * @param a An Int struct.  
  * @param b An Int struct. 
  * @return Int. The result of `a` % `b`.  
  */
  public fun mod(a: Int, b: Int): Int {
    let a_abs = abs(a);
    let b_abs = abs(b);

    let result = a_abs.value % b_abs.value;

    if (is_neg(a) && result != 0)   neg_from_u256(result) else from_u256(result)
  }

  /*
  * @notice It performs `base` ** `exponent`.  
  * @param base An Int struct.  
  * @param exponent The exponent. 
  * @return Int. The result of `base` ** `exponent`.  
  */
  public fun pow(base: Int, exponent: u256): Int {
    let raw_value = math256::pow(abs(base).value, exponent);
    assert!(raw_value <= MAX_I256_AS_U256, EConversionFromU256Overflow);    
    let result = Int { value: raw_value };
    
    if (is_neg(base) && exponent % 2 != 0) flip(result) else result
  }

  // === Bitwise Operations ===  

  /*
  * @notice It performs `self` >> `rhs`.  
  * @param self An Int struct.  
  * @param rhs The value to right-hand shift. 
  * @return Int. The result of `self` >> `rhs`.  
  */
  public fun shr(self: Int, rhs: u8): Int { 
    Int {
      value: if (is_positive(self)) {
        self.value >> rhs
      } else {
        (self.value >> rhs) | (MAX_I256_AS_U256 << ((256 - (rhs as u16)) as u8))
      }
    } 
  }     

  /*
  * @notice It performs `self` << `lhs`.  
  * @param self An Int struct.  
  * @param lhs The value to right-hand shift. 
  * @return Int. The result of `self` << `lhs`.  
  */
  public fun shl(self: Int, lhs: u8): Int {
    Int {
      value: self.value << lhs
    } 
  }

  /*
  * @notice It performs `a` | `b`.  
  * @param a The first operand.   
  * @param b The second operand. 
  * @return Int. The result of `a` | `b`.  
  */
  public fun or(a: Int, b: Int): Int {
    Int {
      value: a.value | b.value
    } 
  }

  /*
  * @notice It performs `a` & `b`.  
  * @param a The first operand.   
  * @param b The second operand. 
  * @return Int. The result of `a` & `b`.  
  */
  public fun and(a: Int, b: Int): Int {
    Int {
      value: a.value & b.value
    } 
  }

  // === Friend only function ===  

  /*
  * @notice It wraps the `self` around the max value.  
  * @param self An Int struct.  
  * @param max The value that the self will wrap around. 
  * @return u256. The result after wrapping around.
  */
  public(friend) fun wrap(self: Int, max: u256): u256 {
    let max = from_u256(max);

    to_u256(if (is_neg(self)) add(self, max) else sub(self, mul(max, div_down(self, max))))
  }  
}