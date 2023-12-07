#[test_only]
module suitears::string_tests {
  use std::ascii::{Self, string, length};

  use sui::test_scenario;
  use sui::test_utils::assert_eq;

  use suitears::string::{
    slice,
    append,
    contains, 
    into_char,
    to_lower_case,
    to_upper_case,
    u128_to_string,
    addr_into_string,
    u128_to_hex_string,
    bytes_to_hex_string,
    u128_to_hex_string_fixed_length, 
  };

  const MAX_U128: u128 = 340282366920938463463374607431768211455;

  #[test]
  fun test_contains() {
    assert_eq(contains(string(b"long text here"), string(b"bull")), false);
    assert_eq(contains(string(b"long text here"), string(b"long ")), true);
  }

  #[test]
  fun test_append() {
    assert_eq(append(string(b"hello"), string(b" world")), string(b"hello world"));
  }

  #[test]
  fun test_slice() {
    let type = string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0::schema::Schema");

    let slice = slice(type, 0, 42);
    assert_eq(string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0"), slice);

    let slice = slice(type, 44, length(&type));
    assert_eq(string(b"schema::Schema"), slice);
  }

  #[test]
  fun test_into_char() {
    assert_eq(into_char(&string(b"sui"), 0), ascii::char(115));
    assert_eq(into_char(&string(b"sui"), 1), ascii::char(117));
    assert_eq(into_char(&string(b"sui"), 2), ascii::char(105));
  }

  #[test]
  public fun test_change_case() {
    let string = ascii::string(b"HeLLo WorLd");
    let lower = to_lower_case(string);
    let upper = to_upper_case(string);
    
    assert_eq(lower, ascii::string(b"hello world"));
    assert_eq(upper, ascii::string(b"HELLO WORLD"));
  }   

  #[test]
  fun test_u128_to_string() {
    assert_eq(b"0", ascii::into_bytes(u128_to_string(0)));
    assert_eq(b"1", ascii::into_bytes(u128_to_string(1)));
    assert_eq(b"257", ascii::into_bytes(u128_to_string(257)));
    assert_eq(b"10", ascii::into_bytes(u128_to_string(10)));
    assert_eq(b"12345678", ascii::into_bytes(u128_to_string(12345678)));
    assert_eq(b"340282366920938463463374607431768211455", ascii::into_bytes(u128_to_string(MAX_U128)));
  }

  #[test]
  fun test_u128_to_hex_string() {
    assert_eq(b"0x00", ascii::into_bytes(u128_to_hex_string(0)));
    assert_eq(b"0x01", ascii::into_bytes(u128_to_hex_string(1)));
    assert_eq(b"0x0101", ascii::into_bytes(u128_to_hex_string(257)));
    assert_eq(b"0xbc614e", ascii::into_bytes(u128_to_hex_string(12345678)));
    assert_eq(b"0xffffffffffffffffffffffffffffffff", ascii::into_bytes(u128_to_hex_string(MAX_U128)));
  }

  #[test]
  fun test_u128_to_hex_string_fixed_length() {
    assert_eq(b"0x00", ascii::into_bytes(u128_to_hex_string_fixed_length(0, 1)));
    assert_eq(b"0x01", ascii::into_bytes(u128_to_hex_string_fixed_length(1, 1)));
    assert_eq(b"0x10", ascii::into_bytes(u128_to_hex_string_fixed_length(16, 1)));
    assert_eq(b"0x0011", ascii::into_bytes(u128_to_hex_string_fixed_length(17, 2)));
    assert_eq(b"0x0000bc614e", ascii::into_bytes(u128_to_hex_string_fixed_length(12345678, 5)));
    assert_eq(b"0xffffffffffffffffffffffffffffffff", ascii::into_bytes(u128_to_hex_string_fixed_length(MAX_U128, 16)));
  }

  #[test]
  fun test_bytes_to_hex_string() {
    assert_eq(b"0x00", ascii::into_bytes(bytes_to_hex_string(x"00")));
    assert_eq(b"0x01", ascii::into_bytes(bytes_to_hex_string(x"01")));
    assert_eq(b"0x1924bacf", ascii::into_bytes(bytes_to_hex_string(x"1924bacf")));
    assert_eq(b"0x8324445443539749823794832789472398748932794327743277489327498732", ascii::into_bytes(bytes_to_hex_string(x"8324445443539749823794832789472398748932794327743277489327498732")));
    assert_eq(b"0xbfee823235227564", ascii::into_bytes(bytes_to_hex_string(x"bfee823235227564")));
    assert_eq(b"0xffffffffffffffffffffffffffffffff", ascii::into_bytes(bytes_to_hex_string(x"ffffffffffffffffffffffffffffffff")));
  }


  #[test]
  public fun test_decompose_type() {
    let scenario = test_scenario::begin(@0x5);
    {
      let type = string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0::schema::Schema");
      let delimeter = string(b"::");
      contains(type, delimeter);

      assert_eq(contains(type, string(b"1a31e")), true);
    };
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_addr_into_string() {
    let scenario = test_scenario::begin(@0x5);
    let _ctx = test_scenario::ctx(&mut scenario);
    {
      let string = addr_into_string(@0x23a);
      assert_eq(string(b"000000000000000000000000000000000000000000000000000000000000023a"), string);
    };
    test_scenario::end(scenario);
  } 
}