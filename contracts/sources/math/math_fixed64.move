// * ALL CREDITS TO APTOS - https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/math_fixed64.move
/// Standard math utilities missing in the Move Language.

module suitears::math_fixed64 {
    use suitears::fixed_point64::{Self, FixedPoint64};

    /// Integer power of a fixed point number
    public fun pow(x: FixedPoint64, n: u64): FixedPoint64 {
        let raw_value = (fixed_point64::get_raw_value(x) as u256);
        fixed_point64::create_from_raw_value((pow_raw(raw_value, (n as u128)) as u128))
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