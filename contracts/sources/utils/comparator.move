/// From https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/comparator.move
module suitears::comparator {
    use std::bcs;
    use std::vector;

    const EQUAL: u8 = 0;
    const SMALLER: u8 = 1;
    const GREATER: u8 = 2;

    struct Result has drop {
        inner: u8,
    }

    public fun is_equal(result: &Result): bool {
        result.inner == EQUAL
    }

    public fun is_smaller_than(result: &Result): bool {
        result.inner == SMALLER
    }

    public fun is_greater_than(result: &Result): bool {
        result.inner == GREATER
    }

    // Performs a comparison of two types after BCS serialization.
    // BCS uses little endian encoding for all integer types,
    // so comparison between primitive integer types will not behave as expected.
    // For example, 1(0x1) will be larger than 256(0x100) after BCS serialization.
    public fun compare<T>(left: &T, right: &T): Result {
        let left_bytes = bcs::to_bytes(left);
        let right_bytes = bcs::to_bytes(right);

        compare_u8_vector(left_bytes, right_bytes)
    }

    // Performs a comparison of two vector<u8>s or byte vectors
    public fun compare_u8_vector(left: vector<u8>, right: vector<u8>): Result {
        let left_length = vector::length(&left);
        let right_length = vector::length(&right);

        let idx = 0;

        while (idx < left_length && idx < right_length) {
            let left_byte = *vector::borrow(&left, idx);
            let right_byte = *vector::borrow(&right, idx);

            if (left_byte < right_byte) {
                return Result { inner: SMALLER }
            } else if (left_byte > right_byte) {
                return Result { inner: GREATER }
            };
            idx = idx + 1;
        };

        if (left_length < right_length) {
            Result { inner: SMALLER }
        } else if (left_length > right_length) {
            Result { inner: GREATER }
        } else {
            Result { inner: EQUAL }
        }
    }
}