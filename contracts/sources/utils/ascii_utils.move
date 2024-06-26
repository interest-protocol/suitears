/*
 * @title ASCII Utils
 *
 * @notice A utility library to operate on ASCII strings.
 *
 * @notice We would like to credit Movemate and Capsules for some function implementations.
 * Movemate - https://github.com/pentagonxyz/movemate/blob/main/sui/sources/to_string.move
 * Capsules - https://github.com/capsule-craft/capsules/blob/master/packages/sui_utils/sources/ascii2.move
 */
module suitears::ascii_utils {
    // === Imports ===

    use std::bcs;
    use std::ascii::{Self, String, Char};

    // === Constants ===

    // @dev A list of all valid HEX characters.
    const HEX_SYMBOLS: vector<u8> = b"0123456789abcdef";

    // === Errors ===

    // @dev If the user tries to slice a string with out-of-bounds indices.
    const EInvalidSlice: u64 = 0;

    // @dev If the user tries to convert a u8 into an invalid ASCII.
    const EInvalidAsciiCharacter: u64 = 2;

    // === Public Functions to manipulate strings ===

    /*
     * @notice It checks if `a` contains `b`.
     *
     * @dev Computes the index of the first occurrence of a string. Returns false if no occurrence is found.
     * @dev Naive implementation of a substring matching algorithm, intended to be used with < 100 length strings.
     *
     * @param a A string.
     * @param b A string.
     * @return bool. True if `a` contains `b`.
     *
     * aborts-if:
     * - `b` is longer than `a`.
     */
    public fun contains(a: String, b: String): bool {
        if (ascii::length(&b) > a.length()) return false;

        let (haystack, needle) = (a, b);

        let (mut i, end) = (0, needle.length() - 1);
        while (i + end < haystack.length()) {
            let mut j = end;
            loop {
                if (into_char(&haystack, i + j) == into_char(&needle, j)) {
                    if (j == 0) {
                        return true
                        // Found the substring
                    } else {
                        j = j - 1;
                    }
                } else {
                    break
                }
            };
            i = i + 1;
        };

        false
        // No result found
    }

    /*
     * @notice Appends `a` + `b`.
     *
     * @param a The first substring.
     * @param b The second substring.
     * @return String. `a` + `b` => "hello" `append` "world" => "helloworld".
     */
    public fun append(a: String, b: String): String {
        let mut i = 0;
        let b_length = b.length();
        let mut a_copy = a;
        while (i < b_length) {
            a_copy.push_char(into_char(&b, i));
            i = i + 1;
        };
        a_copy
    }

    /*
     * @Notice Returns a [i, j) slice of the string starting at index i and going up to, but not including, index j.
     *
     * @param s The string that will be sliced.
     * @param i The first index of the substring.
     * @param j The last index of the substring. This character is not included.
     * @return String The substring.
     *
     * aborts-if
     * - if `j` is greater than `s`.
     * - if `j` is smaller than `i`.
     */
    public fun slice(s: String, i: u64, j: u64): String {
        assert!(j <= ascii::length(&s) && i <= j, EInvalidSlice);

        let bytes = ascii::into_bytes(s);

        let (mut i, mut slice) = (i, vector<u8>[]);

        while (i < j) {
            slice.push_back(bytes[i]);
            i = i + 1;
        };

        slice.to_ascii_string()
    }

    // === Public Functions to convert  from or to strings ===

    /*
     * @notice It returns the `Char` at index `i` from `string`.
     *
     * @dev Similar interface to vector::borrow
     *
     * @param string The string that contains the `Char`.
     * @param i The index of the `Char` we want to grab.
     * @return Char. The `Char` at index `i`.
     *
     * aborts-if
     * - `i` is out of bounds
     */
    public fun into_char(string: &String, i: u64): Char {
        ascii::char(string.as_bytes()[i])
    }

    /*
     * @notice It is lowercase a string.
     *
     * @param string The string we wish to lowercase.
     * @return String. The lowercase `string`.
     */
    public fun to_lower_case(string: String): String {
        let (mut bytes, mut i) = (string.into_bytes(), 0);
        while (i < bytes.length()) {
            let byte = &mut bytes[i];
            if (*byte >= 65u8 && *byte <= 90u8) *byte = *byte + 32u8;
            i = i + 1;
        };

        bytes.to_ascii_string()
    }

    /*
     * @notice It upper cases a string.
     *
     * @param string The string we wish to uppercase.
     * @return String. The uppercased `string`.
     */
    public fun to_upper_case(string: String): String {
        let (mut bytes, mut i) = (string.into_bytes(), 0);
        while (i < bytes.length()) {
            let byte = &mut bytes[i];
            if (*byte >= 97u8 && *byte <= 122u8) *byte = *byte - 32u8;
            i = i + 1;
        };
        bytes.to_ascii_string()
    }

    /*
     * @notice Converts a `u128` to its `ascii::String` decimal representation.
     *
     * @param value A u128.
     * @return String. The string representation of `value`. E.g. 128 => "128".
     */
    public fun u128_to_string(mut value: u128): String {
        if (value == 0) {
            return b"0".to_ascii_string()
        };
        let mut buffer = vector[];
        while (value != 0) {
            buffer.push_back(((48 + value % 10) as u8));
            value = value / 10;
        };
        buffer.reverse();
        buffer.to_ascii_string()
    }

    /*
     * @notice Converts a `u128` to its `ascii::String` hexadecimal representation.
     *
     * @param value A u128.
     * @return String. The HEX string representation of `value`. E.g. 10 => "0xA".
     */
    public fun u128_to_hex_string(value: u128): String {
        if (value == 0) {
            return b"0x00".to_ascii_string()
        };
        let mut temp: u128 = value;
        let mut length: u128 = 0;
        while (temp != 0) {
            length = length + 1;
            temp = temp >> 8;
        };
        u128_to_hex_string_fixed_length(value, length)
    }

    /*
     * @notice Converts a `u128` to its `ascii::String` hexadecimal representation with fixed length (in whole bytes).
     *
     * @dev The returned String is `2 * length + 2`(with '0x') in size.
     *
     * @param value A u128.
     * @param length of the string.
     * @return String. The HEX string representation of `value`. E.g. 10 => "0x0A".
     */
    public fun u128_to_hex_string_fixed_length(mut value: u128, length: u128): String {
        let mut buffer = vector[];
        let hex_symbols = HEX_SYMBOLS;

        let mut i: u128 = 0;
        while (i < length * 2) {
            buffer.push_back(hex_symbols[(value & 0xf as u64)]);
            value = value >> 4;
            i = i + 1;
        };
        assert!(value == 0, 1);
        buffer.append(b"x0");
        buffer.reverse();
        buffer.to_ascii_string()
    }

    /*
     * @notice Converts a `vector<u8>` to its `ascii::String` hexadecimal representation.
     *
     * @param bytes A vector<u8>.
     * @return String. The HEX string representation of `bytes`. E.g. 0b1010 => "0x0A".
     */
    public fun bytes_to_hex_string(bytes: vector<u8>): String {
        let length = vector::length(&bytes);
        let mut buffer = b"0x";
        let hex_symbols = HEX_SYMBOLS;

        let mut i: u64 = 0;
        while (i < length) {
            let byte = bytes[i];
            buffer.push_back(hex_symbols[(byte >> 4 & 0xf as u64)]);
            buffer.push_back(hex_symbols[(byte & 0xf as u64)]);
            i = i + 1;
        };
        buffer.to_ascii_string()
    }

    /*
     * @notice Converts an address `addr` to its `ascii::String` representation.
     *
     * @dev Addresses are 32 bytes, whereas the string-encoded address is 64 bytes.
     * @dev Outputted strings do not include the 0x prefix.
     *
     * @param addr A 32-byte address.
     * @return String. The `ascii::String` representation of `addr`.
     */
    public fun addr_into_string(addr: address): String {
        let mut ascii_bytes = vector[];

        let addr_bytes = bcs::to_bytes(&addr);
        let mut i = 0;
        while (i < addr_bytes.length()) {
            // split the byte into halves
            let low: u8 = addr_bytes[i] % 16u8;
            let high: u8 = addr_bytes[i] / 16u8;
            ascii_bytes.push_back(u8_to_ascii(high));
            ascii_bytes.push_back(u8_to_ascii(low));
            i = i + 1;
        };

        ascii_bytes.to_ascii_string()
    }

    /*
     * @notice Converts a u8 `num` to an ascii character.
     *
     * @param num represents an ASCII character.
     * @return u8. The `ascii::String` code for `num`.
     */
    public fun u8_to_ascii(num: u8): u8 {
        if (num < 10) {
            num + 48
        } else {
            num + 87
        }
    }

    /*
     * @notice Converts an ASCII character to its decimal representation u8.
     *
     * @param char ASCII character.
     * @return u8. The decimal representation of `char`.
     */
    public fun ascii_to_u8(char: u8): u8 {
        assert!(ascii::is_valid_char(char), EInvalidAsciiCharacter);

        if (char < 58) {
            char - 48
        } else {
            char - 87
        }
    }
}
