/// Inspired from https://github.com/pentagonxyz/movemate/blob/main/sui/sources/i64.move
/// @notice Signed 128-bit integers in Move.
/// Uses 2's complement for negative numbers to follow solidity
/// Uses arithmatic shr and shl for negative numbers
module suitears::i64 {

    const MAX_I64_AS_u128: u64 = 0x7FFFFFFFFFFFFFFF;
    const MAX_U64: u64 = 0xFFFFFFFFFFFFFFFF;

    const U128_WITH_FIRST_BIT_SET: u64 = 1 << 63;

    // Compare Results

    const EQUAL: u8 = 0;

    const LESS_THAN: u8 = 1;

    const GREATER_THAN: u8 = 2;

    // ERRORS

    const EConversionFromU64Overflow: u64 = 0;
    const EConversionToU64Underflow: u64 = 1;

    struct I64 has copy, drop, store {
        bits: u64
    }

    public fun from_raw(x: u64): I64 {
      I64 { bits: x }
    }

    public fun from(x: u64): I64 {
        assert!(x <= MAX_I64_AS_u128, EConversionFromU64Overflow);
        I64 { bits: x }
    }

    public fun neg_from(x: u64): I64 {
        let ret = from(x);
        if (ret.bits > 0) *&mut ret.bits = MAX_U64 - ret.bits + 1;
        ret
    }

    public fun bits(x: &I64): u64 {
        x.bits
    }

    public fun as_u128(x: &I64): u64 {
        assert!(is_positive(x), EConversionToU64Underflow);
        x.bits
    }

    public fun as_u64(x: &I64): u64 {
        assert!(is_positive(x), EConversionToU64Underflow);
        (x.bits as u64)
    }

    public fun truncate_to_u8(x: &I64): u8 {
        ((x.bits & 0xFF) as u8)
    }

    public fun zero(): I64 {
        I64 { bits: 0 }
    }

    public fun one(): I64 {
      I64 { bits: 1 }
    }

    public fun max(): I64 {
        I64 { bits: MAX_I64_AS_u128}
    }

    public fun is_neg(x: &I64): bool {
        (x.bits & U128_WITH_FIRST_BIT_SET) != 0
    }

    public fun is_zero(x: &I64): bool {
        x.bits == 0
    }

    public fun is_positive(x: &I64): bool {
        U128_WITH_FIRST_BIT_SET > x.bits
    }

    public fun flip(x: &I64): I64 {
        if (is_neg(x)) { abs(x) } else { neg_from(x.bits) } 
    }

    public fun abs(x: &I64): I64 {
        if (is_neg(x)) from((x.bits ^ MAX_U64) + 1) else *x 
    }

    /// @notice Compare `a` and `b`.
    public fun compare(a: &I64, b: &I64): u8 {
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

    public fun add(a: &I64, b: &I64): I64 {
        if (is_positive(a)) {
            // A is posiyive
            if (is_positive(b)) {
                // A and B are posistive;
                from(a.bits + b.bits)
            } else {
                // A is positive but B is negative
                let b_abs = abs(b);
                if (a.bits >= b_abs.bits) return from(a.bits - b_abs.bits);
                return neg_from(b_abs.bits - a.bits)
            }
        } else {
            // A is negative
            if (is_positive(b)) {
                // A is negative and B is positive
                let a_abs = abs(a);
                if (b.bits >= a_abs.bits) return from(b.bits - a_abs.bits);
                return neg_from(a_abs.bits - b.bits)
            } else {
                // A and B are negative
                neg_from(abs(a).bits + abs(b).bits)
            }
        }
    }

    /// @notice Subtract `a - b`.
    public fun sub(a: &I64, b: &I64): I64 {
        if (is_positive(a)) {
            // A is positive
            if (is_positive(b)) {
                // B is positive
                if (a.bits >= b.bits) return from(a.bits - b.bits); // Return positive
                return neg_from(b.bits - a.bits) // Return negative
            } else {
                // B is negative
                return from(a.bits + abs(b).bits) // Return positive
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
                if (b_abs.bits >= a_abs.bits) return from(b_abs.bits - a_abs.bits); // Return positive
                return neg_from(a_abs.bits - b_abs.bits) // Return negative
            }
        }
    }

    /// @notice Multiply `a * b`.
    public fun mul(a: &I64, b: &I64): I64 {
        if (is_positive(a)) {
            // A is positive
            if (is_positive(b)) {
                // B is positive
                return from(a.bits * b.bits)// Return positive
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
                return from(abs(a).bits * abs(b).bits ) // Return positive
            }
        }
    }

    /// @notice Divide `a / b`.
    public fun div(a: &I64, b: &I64): I64 {
        if (is_positive(a)) {
            // A is positive
            if (is_positive(b)) {
                // B is positive
                return from(a.bits / b.bits) // Return positive
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
                return from(abs(a).bits / abs(b).bits ) // Return positive
            }
        }    
    }

    public fun mod(a: &I64, b: &I64): I64 {
        let a_abs = abs(a);
        let b_abs = abs(b);

        let result = a_abs.bits % b_abs.bits;

       if (is_neg(a) && result != 0)   neg_from(result) else from(result)
    }

    public fun shr(a: &I64, rhs: u8): I64 { 

     I64 {
        bits: if (is_positive(a)) {
        a.bits >> rhs
       } else {
         let mask = (1 << ((64 - (rhs as u16)) as u8)) - 1;
         (a.bits >> rhs) | (mask << ((64 - (rhs as u16)) as u8))
        }
     } 
    }     

    public fun shl(a: &I64, rhs: u8): I64 {
        I64 {
            bits: a.bits << rhs
        } 
    }

    public fun or(a: &I64, b: &I64): I64 {
      I64 {
        bits: a.bits | b.bits
      } 
    }

     public fun and(a: &I64, b: &I64): I64 {
      I64 {
        bits: a.bits & b.bits
      } 
    }
}