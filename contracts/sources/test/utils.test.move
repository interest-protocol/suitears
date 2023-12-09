#[test_only]
module suitears::test_utils {

  use sui::test_utils::assert_eq;

  use suitears::math128;

  use sui::test_scenario::{Self as test, Scenario};

  public fun assert_approx_the_same(x: u256, y: u256, precision: u128) {
    if (x < y) {
      let tmp = x;
      x = y;
      y = tmp;
      };
      let mult = (math128::pow(10, precision) as u256);
      assert_eq((x - y) * mult < x, true);
    }  

  public fun scenario(): Scenario { test::begin(@0x1) }

  public fun people():(address, address) { (@0xBEEF, @0x1337)}    
}