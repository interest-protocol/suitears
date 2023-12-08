#[test_only]
module suitears::comparator_tests {
  use std::vector;
  use std::string;

  use suitears::comparator::{compare, eq, gt, lt, lte, gte};

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

    assert!(eq(&compare(&value0, &value0)), 0);
    assert!(eq(&compare(&value1, &value1)), 1);
    assert!(eq(&compare(&value2, &value2)), 2);
    assert!(lte(&compare(&value2, &value2)), 2);
    assert!(gte(&compare(&value2, &value2)), 2);

    assert!(gt(&compare(&value0, &value1)), 3);
    assert!(gte(&compare(&value0, &value1)), 3);
    assert!(lt(&compare(&value1, &value0)), 4);
    assert!(lte(&compare(&value1, &value0)), 4);

    assert!(lt(&compare(&value0, &value2)), 5);
    assert!(lte(&compare(&value0, &value2)), 5);
    assert!(gt(&compare(&value2, &value0)), 6);
    assert!(gte(&compare(&value2, &value0)), 6);

    assert!(lt(&compare(&value1, &value2)), 7);
    assert!(lte(&compare(&value1, &value2)), 7);    
    assert!(gt(&compare(&value2, &value1)), 8);
    assert!(gte(&compare(&value2, &value1)), 8);    
  }

  #[test]
  public fun test_u128() {
    let value0: u128 = 5;
    let value1: u128 = 152;
    let value2: u128 = 511; // 0x1ff

    assert!(eq(&compare(&value0, &value0)), 0);
    assert!(eq(&compare(&value1, &value1)), 1);
    assert!(eq(&compare(&value2, &value2)), 2);

    assert!(lt(&compare(&value0, &value1)), 2);
    assert!(gt(&compare(&value1, &value0)), 3);

    assert!(lt(&compare(&value0, &value2)), 3);
    assert!(gt(&compare(&value2, &value0)), 4);

    assert!(lt(&compare(&value1, &value2)), 5);
    assert!(gt(&compare(&value2, &value1)), 6);
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

    assert!(eq(&compare(&base, &base)), 0);
    assert!(lte(&compare(&base, &base)), 0);
    assert!(gte(&compare(&base, &base)), 0);
    assert!(lt(&compare(&base, &other_0)), 1);
    assert!(gt(&compare(&other_0, &base)), 2);
    assert!(lt(&compare(&base, &other_1)), 3);
    assert!(gt(&compare(&other_1, &base)), 4);
    assert!(lt(&compare(&base, &other_2)), 5);
    assert!(lte(&compare(&base, &other_2)), 5);
    assert!(gt(&compare(&other_2, &base)), 6);
    assert!(gte(&compare(&other_2, &base)), 6);
  }  

  #[test]
  #[expected_failure]
  public fun test_integer() {
    // 1(0x1) will be larger than 256(0x100) after BCS serialization.
    let value0: u128 = 1;
    let value1: u128 = 256;

    assert!(eq(&compare(&value0, &value0)), 0);
    assert!(eq(&compare(&value1, &value1)), 1);

    assert!(lt(&compare(&value0, &value1)), 2);
    assert!(gt(&compare(&value1, &value0)), 3);
  }    
}