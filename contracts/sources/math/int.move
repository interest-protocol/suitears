/// Inspired from_raw_u256 https://github.com/pentagonxyz/movemate/blob/main/sui/sources/i64.move
/// @notice Signed 256-bit integers in Move.
/// Uses 2's complement for negative numbers to follow solidity
/// Uses arithmatic shr and shl for negative numbers
module suitears::int {

    const MAX_I256_AS_U256: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    const MAX_U256: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    const U256_WITH_FIRST_BIT_SET: u256 = 1 << 255;

    // Compare Results

    const EQUAL: u8 = 0;

    const LESS_THAN: u8 = 1;

    const GREATER_THAN: u8 = 2;

    // ERRORS

    const EConversionFromU256Overflow: u64 = 0;
    const EConversionUnderflow: u64 = 1;

    struct Int has copy, drop, store {
        bits: u256
    }

    public fun from_raw_u8(x: u8): Int {
      Int { bits: (x as u256) }
    }

    public fun from_raw_u16(x: u16): Int {
      Int { bits: (x as u256) }
    }

    public fun from_raw_u32(x: u32): Int {
      Int { bits: (x as u256) }
    }

    public fun from_raw_u64(x: u64): Int {
      Int { bits: (x as u256) }
    }

    public fun from_raw_u128(x: u128): Int {
      Int { bits: (x as u256) }
    }

    public fun from_raw_u256(x: u256): Int {
        assert!(x <= MAX_I256_AS_U256, EConversionFromU256Overflow);
        Int { bits: x }
    }

    public fun neg_from(x: u256): Int {
        let ret = from_raw_u256(x);
        if (ret.bits > 0) *&mut ret.bits = MAX_U256 - ret.bits + 1;
        ret
    }

    public fun bits(x: &Int): u256 {
        x.bits
    }

    public fun as_u8(x: &Int): u8 {
        assert!(is_positive(x), EConversionUnderflow);
        (x.bits as u8)
    }

    public fun as_u16(x: &Int): u16 {
        assert!(is_positive(x), EConversionUnderflow);
        (x.bits as u16)
    }

    public fun as_u32(x: &Int): u32 {
        assert!(is_positive(x), EConversionUnderflow);
        (x.bits as u32)
    }

    public fun as_u64(x: &Int): u64 {
        assert!(is_positive(x), EConversionUnderflow);
        (x.bits as u64)
    }

    public fun as_u128(x: &Int): u128 {
        assert!(is_positive(x), EConversionUnderflow);
        (x.bits as u128)
    }

    public fun as_u256(x: &Int): u256 {
        assert!(is_positive(x), EConversionUnderflow);
        x.bits
    }

    public fun truncate_to_u8(x: &Int): u8 {
        assert!(is_positive(x), EConversionUnderflow);
        ((x.bits & 0xFF) as u8)
    }

    public fun truncate_to_u16(x: &Int): u16 {
        assert!(is_positive(x), EConversionUnderflow);
        ((x.bits & 0xFFFF) as u16)
    }

    public fun truncate_to_u32(x: &Int): u32 {
        assert!(is_positive(x), EConversionUnderflow);
        ((x.bits & 0xFFFFFFFF) as u32)
    }

    public fun truncate_to_u64(x: &Int): u64 {
        assert!(is_positive(x), EConversionUnderflow);
        ((x.bits & 0xFFFFFFFFFFFFFFFF) as u64)
    }

    public fun truncate_to_u128(x: &Int): u128 {
        assert!(is_positive(x), EConversionUnderflow);
        ((x.bits & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) as u128)
    }

    public fun zero(): Int {
        Int { bits: 0 }
    }

    public fun one(): Int {
      Int { bits: 1 }
    }

    public fun max(): Int {
        Int { bits: MAX_I256_AS_U256 }
    }

    public fun is_neg(x: &Int): bool {
        (x.bits & U256_WITH_FIRST_BIT_SET) != 0
    }

    public fun is_zero(x: &Int): bool {
        x.bits == 0
    }

    public fun is_positive(x: &Int): bool {
        U256_WITH_FIRST_BIT_SET > x.bits
    }

    public fun flip(x: &Int): Int {
        if (is_neg(x)) { abs(x) } else { neg_from(x.bits) } 
    }

    public fun abs(x: &Int): Int {
        if (is_neg(x)) from_raw_u256((x.bits ^ MAX_U256) + 1) else *x 
    }

    /// @notice Compare `a` and `b`.
    public fun compare(a: &Int, b: &Int): u8 {
        if (a.bits == b.bits) return EQUAL;
        if (is_positive(a)) {
            // A is positive
            if (is_positive(b)) {
                // A and B are positive
                return if (a.bits > b.bits) GREATER_THAN else LESS_THAN
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
                return if (abs(a).bits > abs(b).bits) LESS_THAN else GREATER_THAN
            }
        }
    }

    public fun eq(a: &Int, b: &Int): bool {
        compare(a, b) == EQUAL
    }

    public fun lt(a: &Int, b: &Int): bool {
        compare(a, b) == LESS_THAN
    }

    public fun lte(a: &Int, b: &Int): bool {
        let pred = compare(a, b);
        pred == LESS_THAN || pred == EQUAL
    }

    public fun gt(a: &Int, b: &Int): bool {
        compare(a, b) == GREATER_THAN
    }

    public fun gte(a: &Int, b: &Int): bool {
        let pred = compare(a, b);
        pred == GREATER_THAN || pred == EQUAL
    }

    public fun add(a: &Int, b: &Int): Int {
        if (is_positive(a)) {
            // A is posiyive
            if (is_positive(b)) {
                // A and B are posistive;
                from_raw_u256(a.bits + b.bits)
            } else {
                // A is positive but B is negative
                let b_abs = abs(b);
                if (a.bits >= b_abs.bits) return from_raw_u256(a.bits - b_abs.bits);
                return neg_from(b_abs.bits - a.bits)
            }
        } else {
            // A is negative
            if (is_positive(b)) {
                // A is negative and B is positive
                let a_abs = abs(a);
                if (b.bits >= a_abs.bits) return from_raw_u256(b.bits - a_abs.bits);
                return neg_from(a_abs.bits - b.bits)
            } else {
                // A and B are negative
                neg_from(abs(a).bits + abs(b).bits)
            }
        }
    }

    /// @notice Subtract `a - b`.
    public fun sub(a: &Int, b: &Int): Int {
        if (is_positive(a)) {
            // A is positive
            if (is_positive(b)) {
                // B is positive
                if (a.bits >= b.bits) return from_raw_u256(a.bits - b.bits); // Return positive
                return neg_from(b.bits - a.bits) // Return negative
            } else {
                // B is negative
                return from_raw_u256(a.bits + abs(b).bits) // Return positive
            }
        } else {
            // A is negative
            if (is_positive(b)) {
                // B is positive
                return neg_from(abs(a).bits + b.bits) // Return negative
            } else {
                // B is negative
                let a_abs = abs(a);
                let b_abs = abs(b);
                if (b_abs.bits >= a_abs.bits) return from_raw_u256(b_abs.bits - a_abs.bits); // Return positive
                return neg_from(a_abs.bits - b_abs.bits) // Return negative
            }
        }
    }

    /// @notice Multiply `a * b`.
    public fun mul(a: &Int, b: &Int): Int {
        if (is_positive(a)) {
            // A is positive
            if (is_positive(b)) {
                // B is positive
                return from_raw_u256(a.bits * b.bits)// Return positive
            } else {
                // B is negative
                return neg_from(a.bits * abs(b).bits) // Return negative
            }
        } else {
            // A is negative
            if (is_positive(b)) {
                // B is positive
                return neg_from(abs(a).bits * b.bits) // Return negative
            } else {
                // B is negative
                return from_raw_u256(abs(a).bits * abs(b).bits ) // Return positive
            }
        }
    }

    /// @notice Divide `a / b`.
    public fun div(a: &Int, b: &Int): Int {
        if (is_positive(a)) {
            // A is positive
            if (is_positive(b)) {
                // B is positive
                return from_raw_u256(a.bits / b.bits) // Return positive
            } else {
                // B is negative
                return neg_from(a.bits / abs(b).bits ) // Return negative
            }
        } else {
            // A is negative
            if (is_positive(b)) {
                // B is positive
                return neg_from(abs(a).bits / b.bits) // Return negative
            } else {
                // B is negative
                return from_raw_u256(abs(a).bits / abs(b).bits ) // Return positive
            }
        }    
    }

    public fun mod(a: &Int, b: &Int): Int {
        let a_abs = abs(a);
        let b_abs = abs(b);

        let result = a_abs.bits % b_abs.bits;

       if (is_neg(a) && result != 0)   neg_from(result) else from_raw_u256(result)
    }

    public fun shr(a: &Int, rhs: u8): Int { 

     Int {
        bits: if (is_positive(a)) {
        a.bits >> rhs
       } else {
         let mask = (1 << ((256 - (rhs as u16)) as u8)) - 1;
         (a.bits >> rhs) | (mask << ((256 - (rhs as u16)) as u8))
        }
     } 
    }     

    public fun shl(a: &Int, rhs: u8): Int {
        Int {
            bits: a.bits << rhs
        } 
    }

    public fun or(a: &Int, b: &Int): Int {
      Int {
        bits: a.bits | b.bits
      } 
    }

     public fun and(a: &Int, b: &Int): Int {
      Int {
        bits: a.bits & b.bits
      } 
    }
}