// * ALL CREDITS TO APTOS - https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/math_fixed64.move
/// Standard math utilities missing in the Move Language.

module suitears::math_fixed64 {
    use suitears::fixed_point64::{Self, FixedPoint64};
    use suitears::math128;

    // Abort code on overflow
    const EOverflowExp: u64 = 1;

    /// Natural log 2 in 32 bit fixed point
    const LN2: u256 = 12786308645202655660;  // ln(2) in fixed 64 representation

        /// Square root of fixed point number
    public fun sqrt(x: FixedPoint64): FixedPoint64 {
        let y = fixed_point64::get_raw_value(x);
        let z = (math128::sqrt_down(y) << 32 as u256);
        z = (z + ((y as u256) << 64) / z) >> 1;
        fixed_point64::create_from_raw_value((z as u128))
    }

    /// Exponent function with a precission of 9 digits.
    public fun exp(x: FixedPoint64): FixedPoint64 {
        let raw_value = (fixed_point64::get_raw_value(x) as u256);
        fixed_point64::create_from_raw_value((exp_raw(raw_value) as u128))
    }

        // Return log2(x) as FixedPoint64
    public fun log2(x: u128): FixedPoint64 {
        let integer_part = (math128::log2_down(x) as u8);
        // Normalize x to [1, 2) in fixed point 63. To ensure x is smaller then 1<<64
        if (x >= 1 << 63) {
            x = x >> (integer_part - 63);
        } else {
            x = x << (63 - integer_part);
        };
        let frac = 0;
        let delta = 1 << 63;
        while (delta != 0) {
            // log x = 1/2 log x^2
            // x in [1, 2)
            x = (x * x) >> 63;
            // x is now in [1, 4)
            // if x in [2, 4) then log x = 1 + log (x / 2)
            if (x >= (2 << 63)) { frac = frac + delta; x = x >> 1; };
            delta = delta >> 1;
        };
        fixed_point64::create_from_raw_value (((integer_part as u128) << 64) + frac)
    }

    /// Because log2 is negative for values < 1 we instead return log2(x) + 64 which
    /// is positive for all values of x.
    public fun log2_plus_64(x: FixedPoint64): FixedPoint64 {
        let raw_value = (fixed_point64::get_raw_value(x) as u128);
        log2(raw_value)
    }

    public fun ln_plus_32ln2(x: FixedPoint64): FixedPoint64 {
        let raw_value = fixed_point64::get_raw_value(x);
        let x = (fixed_point64::get_raw_value(log2(raw_value)) as u256);
        fixed_point64::create_from_raw_value(((x * LN2) >> 64 as u128))
    }

    /// Integer power of a fixed point number
    public fun pow(x: FixedPoint64, n: u64): FixedPoint64 {
        let raw_value = (fixed_point64::get_raw_value(x) as u256);
        fixed_point64::create_from_raw_value((pow_raw(raw_value, (n as u128)) as u128))
    }

    /// Specialized function for x * y / z that omits intermediate shifting
    public fun mul_div_down(x: FixedPoint64, y: FixedPoint64, z: FixedPoint64): FixedPoint64 {
        let a = fixed_point64::get_raw_value(x);
        let b = fixed_point64::get_raw_value(y);
        let c = fixed_point64::get_raw_value(z);
        fixed_point64::create_from_raw_value (math128::mul_div_down(a, b, c))
    }

    /// Specialized function for x * y / z that omits intermediate shifting
    public fun mul_div_up(x: FixedPoint64, y: FixedPoint64, z: FixedPoint64): FixedPoint64 {
        let a = fixed_point64::get_raw_value(x);
        let b = fixed_point64::get_raw_value(y);
        let c = fixed_point64::get_raw_value(z);
        fixed_point64::create_from_raw_value(math128::mul_div_up(a, b, c))
    }

    // Calculate e^x where x and the result are fixed point numbers
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

    // Calculate x to the power of n, where x and the result are fixed point numbers.
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