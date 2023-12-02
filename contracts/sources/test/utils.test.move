#[test_only]
module suitears::test_utils {

  use sui::test_utils::assert_eq;

  use suitears::math128;

  public fun assert_approx_the_same(x: u256, y: u256, precision: u128) {
    if (x < y) {
      let tmp = x;
      x = y;
      y = tmp;
      };
      let mult = (math128::pow(10, precision) as u256);
      assert_eq((x - y) * mult < x, true);
    }  
}