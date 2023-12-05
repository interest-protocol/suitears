#[test_only]
module suitears::fixed_point64_tests {

  use sui::test_utils::assert_eq;

  use suitears::fixed_point64;
  use suitears::test_utils::assert_approx_the_same;

  #[test]
  fun test_sub() {
    let x = fixed_point64::from_rational(5, 1);
    let y = fixed_point64::from_rational(3, 1);
    let result = fixed_point64::sub(x, y);

    assert_eq(fixed_point64::value(result), 2 << 64);

    let x = fixed_point64::from_rational(5, 1);
    let result = fixed_point64::sub(x, x);

    assert_eq(fixed_point64::value(result), 0);
  }

  #[test]
  fun test_add() {
    let x = fixed_point64::from_rational(5, 1);
    let y = fixed_point64::from_rational(3, 1);
    let result = fixed_point64::add(x, y);

    assert_eq(fixed_point64::value(result), 8 << 64);

    let x = fixed_point64::from_raw_value(340282366920938463463374607431768211455);
    let y = fixed_point64::from_raw_value(0);
    let result = fixed_point64::add(x, y);

    assert_eq(fixed_point64::value(result), 340282366920938463463374607431768211455);
  }

  #[test]
  fun test_mul() {
    let result = fixed_point64::mul(fixed_point64::from(5), fixed_point64::from(3));

    assert_eq(result, fixed_point64::from(15));

    let result = fixed_point64::mul(fixed_point64::from_raw_value(340282366920938463463374607431768211455 / 2), fixed_point64::from(2));

    assert_eq(result, fixed_point64::from_raw_value(340282366920938463463374607431768211454));

    let result = fixed_point64::mul(fixed_point64::from_rational(1, 3), fixed_point64::from(9));    

    assert_eq(fixed_point64::to_u128(result), 3);   
  }

  #[test]
  fun test_div() {
    let result = fixed_point64::div(fixed_point64::from(9), fixed_point64::from(4));

    assert_eq(fixed_point64::value(result), ((((9 as u256) << 128) / (4 << 64)) as u128));      
  }

  #[test]
  fun test_pow() {
    let result = fixed_point64::pow(fixed_point64::from_raw_value(18468802611690918839), 580);
    assert_approx_the_same((fixed_point64::value(result) as u256), 1 << 65, 16);
  }

  #[test]
  fun test_mul_div() {
    let result = fixed_point64::mul_div(fixed_point64::from(5), fixed_point64::from(2), fixed_point64::from(3));

    assert_eq(fixed_point64::value(result), ((((5 as u256) << 64) * (2 << 64) / (3 << 64)) as u128));      
  } 

  #[test]
  fun test_sqrt() {
    let result = fixed_point64::sqrt(fixed_point64::from(1));
    assert_eq(fixed_point64::value(result), 1 << 64);

    let result = fixed_point64::sqrt(fixed_point64::from(2));
    assert_approx_the_same((fixed_point64::value(result) as u256), 26087635650665564424, 16);
  }

  #[test]
  fun test_exp() {
    assert_eq(fixed_point64::exp(fixed_point64::from_raw_value(0)), fixed_point64::from(1));
    assert_approx_the_same(
      (fixed_point64::value(fixed_point64::exp(fixed_point64::from(1))) as u256),
      50143449209799256682,
      16
    );

    assert_approx_the_same(
      (fixed_point64::value(fixed_point64::exp(fixed_point64::from(10))) as u256),
      406316577365116946489258,
      16
    );
  } 

  #[test]
  fun test_mul_u128() {
    let y = fixed_point64::from_rational(5, 1);
    let result = fixed_point64::mul_u128(3, y);

    assert_eq(result, 15);

    let y = fixed_point64::from_raw_value(340282366920938463463374607431768211455 / 2);
    let result = fixed_point64::mul_u128(2, y);

    assert_eq(result, 340282366920938463463374607431768211455 >> 64);

    let y = fixed_point64::from_rational(1, 3); // 0.33
    let result = fixed_point64::mul_u128(9, y);

    assert_eq(result, 2);

    let result = fixed_point64::mul_u128(9, fixed_point64::from_raw_value(fixed_point64::value(y) + 1));

    assert_eq(result, 3);
  }

  #[test]
  fun test_div_up_u128() {
    let y = fixed_point64::from_rational(4, 1);
    let result = fixed_point64::div_up_u128(9, y);

    assert_eq(result, 3);    
  }

  #[test]
  fun test_div_down_u128() {
    let y = fixed_point64::from_rational(4, 1);
    let result = fixed_point64::div_down_u128(9, y);

    assert_eq(result, 2);    
  }

  #[test]
  fun test_max() {
    let x = fixed_point64::from_rational(2, 1);
    let y = fixed_point64::from_rational(1, 1);
    let result = fixed_point64::max(x, y);
  
    assert_eq(fixed_point64::value(result), 2 << 64);

    let result = fixed_point64::max(y, x);
  
    assert_eq(fixed_point64::value(result), 2 << 64);
  }

  #[test]
  fun test_min() {
    let x = fixed_point64::from_rational(2, 1);
    let y = fixed_point64::from_rational(1, 1);
    let result = fixed_point64::min(x, y);
  
    assert_eq(fixed_point64::value(result), 1 << 64);

    let result = fixed_point64::min(y, x);
  
    assert_eq(fixed_point64::value(result), 1 << 64);
  }

  #[test]
  fun test_create_zero() {
    assert_eq(fixed_point64::is_zero(fixed_point64::from_rational(0, 1)), true);
    assert_eq(fixed_point64::is_zero(fixed_point64::from_raw_value(0)), true);
    assert_eq(fixed_point64::is_zero(fixed_point64::from(0)), true);
  }

  #[test]
  fun test_conversion_functions() {
    let x = fixed_point64::from_rational(499, 1000); // 0.499
    let result = fixed_point64::to_u128(x);
    assert_eq(result, 0);    

    let x = fixed_point64::from_rational(1, 2); // 0.5
    let result = fixed_point64::to_u128(x);
    assert_eq(result, 1);     

    let x = fixed_point64::from_rational(1, 1); // 1
    let result = fixed_point64::to_u128_up(x);
    assert_eq(result, 1); 

    let x = fixed_point64::from_rational(499, 1000); // 0.499
    let result = fixed_point64::to_u128_up(x);
    assert_eq(result, 1);

    let x = fixed_point64::from_rational(499, 1000); // 0.499
    let result = fixed_point64::to_u128_down(x);
    assert_eq(result, 0);

    let x = fixed_point64::from_rational(1, 2); // 0.5
    let result = fixed_point64::to_u128_down(x);
    assert_eq(result, 0); 

    let x = fixed_point64::from_rational(7, 2); // 3.5
    let result = fixed_point64::to_u128_down(x);
    assert_eq(result, 3);  
  }

  #[test]
  fun test_comparasion_functions() {
    let one = fixed_point64::from(1);
    let two = fixed_point64::from(2);
    let three = fixed_point64::from(3);

    assert_eq(fixed_point64::is_zero(one), false);

    assert_eq(fixed_point64::lt(one, two), true);
    assert_eq(fixed_point64::lt(two, one), false);
    
    assert_eq(fixed_point64::lte(one, two), true);
    assert_eq(fixed_point64::lte(two, two), true);
    assert_eq(fixed_point64::lte(three, two), false);

    assert_eq(fixed_point64::eq(one, one), true);
    assert_eq(fixed_point64::eq(two, one), false);

    assert_eq(fixed_point64::gt(one, one), false);
    assert_eq(fixed_point64::gt(two, one), true);

    assert_eq(fixed_point64::gte(two, two), true);
    assert_eq(fixed_point64::gt(two, one), true);
    assert_eq(fixed_point64::gt(two, three), false);
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::ENegativeResult)] 
  fun test_underflow_sub() {
    let x = fixed_point64::from_rational(3, 1);
    let y = fixed_point64::from_rational(5, 1);
    fixed_point64::sub(x, y);
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EOutOfRange)] 
  fun test_overflow_add() {
    let x = fixed_point64::from_raw_value(340282366920938463463374607431768211455);
    let y = fixed_point64::from_raw_value(1);
    fixed_point64::add(x, y);
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EMultiplicationOverflow)] 
  fun test_overflow_mul_u128() {
    let y = fixed_point64::from_raw_value(340282366920938463463374607431768211455);
    fixed_point64::mul_u128(((340282366920938463463374607431768211455 << 64) + 1 / 340282366920938463463374607431768211455), y);
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EZeroDivision)] 
  fun test_zero_division_div() {
    fixed_point64::div(fixed_point64::from(1), fixed_point64::from(0));
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EZeroDivision)] 
  fun test_zero_division_div_up() {
    fixed_point64::div_up_u128(1, fixed_point64::from_raw_value(0));
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EDivisionOverflow)] 
  fun test_overflow_div_up() {
    fixed_point64::div_up_u128(1 << 64, fixed_point64::from_raw_value(1));
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EDivisionOverflow)] 
  fun test_overflow_div_down() {
    fixed_point64::div_down_u128(1 << 64, fixed_point64::from_raw_value(1));
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EZeroDivision)] 
  fun test_zero_division_div_down() {
    fixed_point64::div_down_u128(1, fixed_point64::from_raw_value(0));
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EZeroDivision)] 
  fun test_zero_division_from_rational() {
    fixed_point64::from_rational(3, 0);
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EOutOfRange)] 
  fun test_overflow_from_rational() {
    fixed_point64::from_rational(1 << 64, 1);
  }

  #[test]
  #[expected_failure(abort_code = fixed_point64::EOutOfRange)] 
  fun test_underflow_from_rational() {
    fixed_point64::from_rational(1, 2 * (1 << 64));
  }  
}