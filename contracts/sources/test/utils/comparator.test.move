#[test_only]
module suitears::comparator_tests {
  use std::vector;
  use std::string;

  use suitears::comparator::{compare, is_equal, is_greater_than, is_smaller_than};

  struct Complex has drop {
    value0: vector<u128>,
    value1: u8,
    value2: u64,
  }

  #[test]
  public fun test_strings() {
    let value0 = string::utf8(b"alpha");
    let value1 = string::utf8(b"beta");
    let value2 = string::utf8(b"betaa");

    assert!(is_equal(&compare(&value0, &value0)), 0);
    assert!(is_equal(&compare(&value1, &value1)), 1);
    assert!(is_equal(&compare(&value2, &value2)), 2);

    assert!(is_greater_than(&compare(&value0, &value1)), 3);
    assert!(is_smaller_than(&compare(&value1, &value0)), 4);

    assert!(is_smaller_than(&compare(&value0, &value2)), 5);
    assert!(is_greater_than(&compare(&value2, &value0)), 6);

    assert!(is_smaller_than(&compare(&value1, &value2)), 7);
    assert!(is_greater_than(&compare(&value2, &value1)), 8);
  }

  #[test]
  public fun test_u128() {
    let value0: u128 = 5;
    let value1: u128 = 152;
    let value2: u128 = 511; // 0x1ff

    assert!(is_equal(&compare(&value0, &value0)), 0);
    assert!(is_equal(&compare(&value1, &value1)), 1);
    assert!(is_equal(&compare(&value2, &value2)), 2);

    assert!(is_smaller_than(&compare(&value0, &value1)), 2);
    assert!(is_greater_than(&compare(&value1, &value0)), 3);

    assert!(is_smaller_than(&compare(&value0, &value2)), 3);
    assert!(is_greater_than(&compare(&value2, &value0)), 4);

    assert!(is_smaller_than(&compare(&value1, &value2)), 5);
    assert!(is_greater_than(&compare(&value2, &value1)), 6);
  }

  #[test]
  public fun test_complex() {
    let value0_0 = vector::empty();
    
    vector::push_back(&mut value0_0, 10);
    vector::push_back(&mut value0_0, 9);
    vector::push_back(&mut value0_0, 5);

    let value0_1 = vector::empty();
    
    vector::push_back(&mut value0_1, 10);
    vector::push_back(&mut value0_1, 9);
    vector::push_back(&mut value0_1, 5);
    vector::push_back(&mut value0_1, 1);

    let base = Complex {
      value0: value0_0,
      value1: 13,
      value2: 41,
    };

    let other_0 = Complex {
      value0: value0_1,
      value1: 13,
      value2: 41,
    };

    let other_1 = Complex {
      value0: copy value0_0,
      value1: 14,
      value2: 41,
    };

    let other_2 = Complex {
      value0: value0_0,
      value1: 13,
      value2: 42,
    };

    assert!(is_equal(&compare(&base, &base)), 0);
    assert!(is_smaller_than(&compare(&base, &other_0)), 1);
    assert!(is_greater_than(&compare(&other_0, &base)), 2);
    assert!(is_smaller_than(&compare(&base, &other_1)), 3);
    assert!(is_greater_than(&compare(&other_1, &base)), 4);
    assert!(is_smaller_than(&compare(&base, &other_2)), 5);
    assert!(is_greater_than(&compare(&other_2, &base)), 6);
  }  

  #[test]
  #[expected_failure]
  public fun test_integer() {
    // 1(0x1) will be larger than 256(0x100) after BCS serialization.
    let value0: u128 = 1;
    let value1: u128 = 256;

    assert!(is_equal(&compare(&value0, &value0)), 0);
    assert!(is_equal(&compare(&value1, &value1)), 1);

    assert!(is_smaller_than(&compare(&value0, &value1)), 2);
    assert!(is_greater_than(&compare(&value1, &value0)), 3);
  }    
}