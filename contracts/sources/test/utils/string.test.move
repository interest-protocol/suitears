module suitears::string_tests {
  use std::ascii;

  use suitears::string::{
    slice,
    contains, 
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
    assert!(b"0x00" == ascii::into_bytes(bytes_to_hex_string(x"00")), 1);
    assert!(b"0x01" == ascii::into_bytes(bytes_to_hex_string(x"01")), 1);
    assert!(b"0x1924bacf" == ascii::into_bytes(bytes_to_hex_string(x"1924bacf")), 1);
    assert!(b"0x8324445443539749823794832789472398748932794327743277489327498732" == ascii::into_bytes(bytes_to_hex_string(x"8324445443539749823794832789472398748932794327743277489327498732")), 1);
    assert!(b"0xbfee823235227564" == ascii::into_bytes(bytes_to_hex_string(x"bfee823235227564")), 1);
    assert!(b"0xffffffffffffffffffffffffffffffff" == ascii::into_bytes(bytes_to_hex_string(x"ffffffffffffffffffffffffffffffff")), 1);
  }

  #[test_only]
  use std::ascii::{string, length};
  #[test_only]
  use sui::test_scenario;

  #[test]
  public fun test_contains() {
    let my_string = string(b"long text here");
    let i = contains(&my_string, &string(b"bull"));
    assert!(i == false, 11);
  }

  #[test]
  public fun test_decompose_type() {
    let scenario = test_scenario::begin(@0x5);
    {
      let type = string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0::schema::Schema");
      let delimeter = string(b"::");
      contains(&type, &delimeter);

      let slice = slice(type, 0, 42);
      assert!(string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0") == slice, 0);

      let slice = slice(type, 44, length(&type));
      assert!(string(b"schema::Schema") == slice, 0);

      let i = contains(&type, &string(b"1a31e"));
      assert!(i == true, 12);

      // debug::print(&utf8(into_bytes(ascii2::slice(&type, i + 2, length(&type)))));
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