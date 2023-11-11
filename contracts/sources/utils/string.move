// Credit https://github.com/pentagonxyz/movemate/blob/main/sui/sources/to_string.move
// Credit https://github.com/capsule-craft/capsules/blob/master/packages/sui_utils/sources/ascii2.move

module suitears::string {
    use std::ascii::{Self, String, Char};
    use std::vector;
    use std::bcs;
    
    use sui::object::{Self, ID};

    const EInvalidSubString: u64 = 0;
    const EInvalidSlice: u64 = 1;
    const EInvalidAsciiCharacter: u64 = 2;

    const HEX_SYMBOLS: vector<u8> = b"0123456789abcdef";

    #[test_only]
    const MAX_U128: u128 = 340282366920938463463374607431768211455;

    // Appends a string.
    public fun append(s: &mut String, r: String) {
        let i = 0;
        while (i < ascii::length(&r)) {
            ascii::push_char(s, into_char(&r, i));
            i = i + 1;
        };
    }

    // Returns a [i, j) slice of the string starting at index i and going up to, but not including, index j
    // Aborts if j is greater than the length of the string
    public fun sub_string(s: &String, i: u64, j: u64): String {
        assert!(j <= ascii::length(s) && i <= j, EInvalidSubString);

        let bytes = ascii::into_bytes(*s);
        let slice = slice(&bytes, i, j);
        ascii::string(slice)
    }

    // Computes the index of the first occurrence of a string. Returns false if no occurrence found.
    // Naive implementation of a substring matching algorithm, intended to be used with < 100 length strings.
    // More efficient algorithms are possible for larger strings.
    public fun contains_sub_string(s: &String, r: &String): bool {
        if (ascii::length(r) > ascii::length(s)) return false;

        let (haystack, needle) = (s, r);
        
        let (i, end) = (0, ascii::length(needle) - 1);
        while (i + end < ascii::length(haystack)) {
            let j = end;
            loop {
                if (into_char(haystack, i + j) == into_char(needle, j)) {
                    if (j == 0) {
                        return true // Found the substring
                    } else {
                        j = j - 1;
                    }
                } else {
                    break
                }
            };
            i = i + 1;
        };

        false // No result found
    }

    // Similar interface to vector::borrow
    public fun into_char(string: &String, i: u64): Char {
        ascii::char(
            *vector::borrow(
                &ascii::into_bytes(*string), i))
    }

    public fun to_upper_case(string: String): String {
        let (bytes, i) = (ascii::into_bytes(string), 0);
        while (i < vector::length(&bytes)) {
            let byte = vector::borrow_mut(&mut bytes, i);
            if (*byte >= 97u8 && *byte <= 122u8) *byte = *byte - 32u8;
            i = i + 1;
        };
        ascii::string(bytes)
    }

    public fun to_lower_case(string: String): String {
        let (bytes, i) = (ascii::into_bytes(string), 0);
        while (i < vector::length(&bytes)) {
            let byte = vector::borrow_mut(&mut bytes, i);
            if (*byte >= 65u8 && *byte <= 90u8) *byte = *byte + 32u8;
            i = i + 1;
        };
        ascii::string(bytes)
    }

    /// @dev Converts a `u128` to its `ascii::String` decimal representation.
    public fun u128_to_string(value: u128): String {
        if (value == 0) {
            return ascii::string(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        ascii::string(buffer)
    }

    /// @dev Converts a `u128` to its `ascii::String` hexadecimal representation.
    public fun u128_to_hex_string(value: u128): String {
        if (value == 0) {
            return ascii::string(b"0x00")
        };
        let temp: u128 = value;
        let length: u128 = 0;
        while (temp != 0) {
            length = length + 1;
            temp = temp >> 8;
        };
        u128_to_hex_string_fixed_length(value, length)
    }

    /// @dev Converts a `u128` to its `ascii::String` hexadecimal representation with fixed length (in whole bytes).
    /// so the returned String is `2 * length + 2`(with '0x') in size
    public fun u128_to_hex_string_fixed_length(value: u128, length: u128): String {
        let buffer = vector::empty<u8>();

        let i: u128 = 0;
        while (i < length * 2) {
            vector::push_back(&mut buffer, *vector::borrow(&mut HEX_SYMBOLS, (value & 0xf as u64)));
            value = value >> 4;
            i = i + 1;
        };
        assert!(value == 0, 1);
        vector::append(&mut buffer, b"x0");
        vector::reverse(&mut buffer);
        ascii::string(buffer)
    }

    /// @dev Converts a `vector<u8>` to its `ascii::String` hexadecimal representation.
    /// so the returned String is `2 * length + 2`(with '0x') in size
    public fun bytes_to_hex_string(bytes: &vector<u8>): String {
        let length = vector::length(bytes);
        let buffer = b"0x";

        let i: u64 = 0;
        while (i < length) {
            let byte = *vector::borrow(bytes, i);
            vector::push_back(&mut buffer, *vector::borrow(&mut HEX_SYMBOLS, (byte >> 4 & 0xf as u64)));
            vector::push_back(&mut buffer, *vector::borrow(&mut HEX_SYMBOLS, (byte & 0xf as u64)));
            i = i + 1;
        };
        ascii::string(buffer)
    }

    // Addresses are 32 bytes, whereas the string-encoded address is 64 bytes.
    // Outputted strings do not include the 0x prefix.
    public fun addr_into_string(addr: address): String {
        let ascii_bytes = vector::empty<u8>();

        let addr_bytes = bcs::to_bytes(&addr);
        let i = 0;
        while (i < vector::length(&addr_bytes)) {
            // split the byte into halves
            let low: u8 = *vector::borrow(&addr_bytes, i) % 16u8;
            let high: u8 = *vector::borrow(&addr_bytes, i) / 16u8;
            vector::push_back(&mut ascii_bytes, u8_to_ascii(high));
            vector::push_back(&mut ascii_bytes, u8_to_ascii(low));
            i = i + 1;
        };

        ascii::string(ascii_bytes)
    }

    public fun ascii_into_id(str: String): ID {
        ascii_bytes_into_id(ascii::into_bytes(str))
    }

    // Must be ascii-bytes
    public fun ascii_bytes_into_id(ascii_bytes: vector<u8>): ID {
        let (i, addr_bytes) = (0, vector::empty<u8>());

        // combine every pair of bytes; we will go from 64 bytes down to 32
        while (i < vector::length(&ascii_bytes)) {
            let low: u8 = ascii_to_u8(*vector::borrow(&ascii_bytes, i + 1));
            let high: u8 = ascii_to_u8(*vector::borrow(&ascii_bytes, i)) * 16u8;
            vector::push_back(&mut addr_bytes, low + high);
            i = i + 2;
        };

        object::id_from_bytes(addr_bytes)
    }

    public fun u8_to_ascii(num: u8): u8 {
        if (num < 10) {
            num + 48
        } else {
            num + 87
        }
    }

    public fun ascii_to_u8(char: u8): u8 {
        assert!(ascii::is_valid_char(char), EInvalidAsciiCharacter);

        if (char < 58) {
            char - 48
        } else {
            char - 87
        }
    }

    // Takes a slice of a vector from the start-index up to, but not including, the end-index.
    // Does not modify the original vector
    fun slice<T: copy>(vec: &vector<T>, start: u64, end: u64): vector<T> {
        assert!(end >= start, EInvalidSlice);

        let (i, slice) = (start, vector::empty<T>());
        while (i < end) {
            vector::push_back(&mut slice, *vector::borrow(vec, i));
            i = i + 1;
        };

        slice
    }

    #[test]
    fun test_to_string() {
        assert!(b"0" == ascii::into_bytes(u128_to_string(0)), 1);
        assert!(b"1" == ascii::into_bytes(u128_to_string(1)), 1);
        assert!(b"257" == ascii::into_bytes(u128_to_string(257)), 1);
        assert!(b"10" == ascii::into_bytes(u128_to_string(10)), 1);
        assert!(b"12345678" == ascii::into_bytes(u128_to_string(12345678)), 1);
        assert!(b"340282366920938463463374607431768211455" == ascii::into_bytes(u128_to_string(MAX_U128)), 1);
    }

    #[test]
    fun test_to_hex_string() {
        assert!(b"0x00" == ascii::into_bytes(u128_to_hex_string(0)), 1);
        assert!(b"0x01" == ascii::into_bytes(u128_to_hex_string(1)), 1);
        assert!(b"0x0101" == ascii::into_bytes(u128_to_hex_string(257)), 1);
        assert!(b"0xbc614e" == ascii::into_bytes(u128_to_hex_string(12345678)), 1);
        assert!(b"0xffffffffffffffffffffffffffffffff" == ascii::into_bytes(u128_to_hex_string(MAX_U128)), 1);
    }

    #[test]
    fun test_to_hex_string_fixed_length() {
        assert!(b"0x00" == ascii::into_bytes(u128_to_hex_string_fixed_length(0, 1)), 1);
        assert!(b"0x01" == ascii::into_bytes(u128_to_hex_string_fixed_length(1, 1)), 1);
        assert!(b"0x10" == ascii::into_bytes(u128_to_hex_string_fixed_length(16, 1)), 1);
        assert!(b"0x0011" == ascii::into_bytes(u128_to_hex_string_fixed_length(17, 2)), 1);
        assert!(b"0x0000bc614e" == ascii::into_bytes(u128_to_hex_string_fixed_length(12345678, 5)), 1);
        assert!(b"0xffffffffffffffffffffffffffffffff" == ascii::into_bytes(u128_to_hex_string_fixed_length(MAX_U128, 16)), 1);
    }

    #[test]
    fun test_bytes_to_hex_string() {
        assert!(b"0x00" == ascii::into_bytes(bytes_to_hex_string(&x"00")), 1);
        assert!(b"0x01" == ascii::into_bytes(bytes_to_hex_string(&x"01")), 1);
        assert!(b"0x1924bacf" == ascii::into_bytes(bytes_to_hex_string(&x"1924bacf")), 1);
        assert!(b"0x8324445443539749823794832789472398748932794327743277489327498732" == ascii::into_bytes(bytes_to_hex_string(&x"8324445443539749823794832789472398748932794327743277489327498732")), 1);
        assert!(b"0xbfee823235227564" == ascii::into_bytes(bytes_to_hex_string(&x"bfee823235227564")), 1);
        assert!(b"0xffffffffffffffffffffffffffffffff" == ascii::into_bytes(bytes_to_hex_string(&x"ffffffffffffffffffffffffffffffff")), 1);
    }

    #[test_only]
    use std::ascii::{string, length};
    #[test_only]
    use sui::test_scenario;

    #[test]
    public fun test_contains() {
        let my_string = string(b"long text here");
        let i = contains_sub_string(&my_string, &string(b"bull"));
        assert!(i == false, 11);
    }

    #[test]
    public fun test_decompose_type() {
        let scenario = test_scenario::begin(@0x5);
        {
            let type = string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0::schema::Schema");
            let delimeter = string(b"::");
            contains_sub_string(&type, &delimeter);

            let slice = sub_string(&type, 0, 42);
            assert!(string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0") == slice, 0);

            let slice = sub_string(&type, 44, length(&type));
            assert!(string(b"schema::Schema") == slice, 0);

            let i = contains_sub_string(&type, &string(b"1a31e"));
            assert!(i == true, 12);

            // debug::print(&utf8(into_bytes(ascii2::sub_string(&type, i + 2, length(&type)))));
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_addr_into_string() {
        let scenario = test_scenario::begin(@0x5);
        let _ctx = test_scenario::ctx(&mut scenario);
        {
            let string = addr_into_string(@0x23a);
            assert!(string(b"000000000000000000000000000000000000000000000000000000000000023a") == string, 0);
        };
        test_scenario::end(scenario);
    }
    
    #[test]
    public fun test_change_case() {
        let string = ascii::string(b"HeLLo WorLd");
        let lower = to_lower_case(string);
        let upper = to_upper_case(string);
        
        assert!(lower == ascii::string(b"hello world"), 0);
        assert!(upper == ascii::string(b"HELLO WORLD"), 0);
    }
}