#[test_only]
module suitears::fund_tests {

  use sui::test_utils::assert_eq;

  use suitears::fund;
  use suitears::math64;

  #[test]
  fun test_case_one() {
    let pool = fund::empty();

    // Fund starts empty
    assert_eq(fund::underlying(&pool), 0);
    assert_eq(fund::shares(&pool), 0);

    // Predicts the right amount of shares and underlying when it is empty
    assert_eq(fund::to_underlying(&pool, 1000, true), 1000);
    assert_eq(fund::to_underlying(&pool, 1000, true), 1000);
    assert_eq(fund::to_shares(&pool, 1234, true), 1234);
    assert_eq(fund::to_shares(&pool, 1234, true), 1234);

    // No updates
    assert_eq(fund::underlying(&pool), 0);
    assert_eq(fund::shares(&pool), 0);

    // Several deposits and burns without profits
    assert_eq(fund::add_underlying(&mut pool, 1234, true), 1234);   
    assert_eq(fund::underlying(&pool), 1234);
    assert_eq(fund::shares(&pool), 1234);

    // Several deposits and burns without profits
    assert_eq(fund::add_underlying(&mut pool, 1234, true), 1234);   
    assert_eq(fund::underlying(&pool), 1234 * 2);
    assert_eq(fund::shares(&pool), 1234 * 2);

    // Several deposits and burns without profits
    let shares_burned = math64::mul_div_down(437,2468,2468);
    assert_eq(fund::sub_underlying(&mut pool, 437, false), shares_burned);   
    assert_eq(fund::underlying(&pool), 2468 - 437);
    assert_eq(fund::shares(&pool), 2468 - shares_burned);    

    // Several deposits and burns without profits
    let underlying_burned = math64::mul_div_up(273,2468 - 437,2468 - shares_burned);
    assert_eq(fund::sub_shares(&mut pool, 273, true), underlying_burned);   
    assert_eq(fund::underlying(&pool), 2468 - 437 - underlying_burned);
    assert_eq(fund::shares(&pool), 2468 - shares_burned - 273); 

    // Add profits to add a twist
    let profit = 123;
    fund::add_profit(&mut pool, profit);

    let new_shares = math64::mul_div_up(1234, 2468 - shares_burned - 273, 2468 + profit - 437 - underlying_burned);
    assert_eq(fund::add_underlying(&mut pool, 1234, true), new_shares);   
    assert_eq(fund::underlying(&pool), 1234 + 2468 + profit - 437 - underlying_burned);
    assert_eq(fund::shares(&pool), new_shares + 2468 - shares_burned - 273);

    let current_shares = fund::shares(&pool);
    let current_underlying = fund::underlying(&pool);

    let shares_burned = math64::mul_div_down(437, current_shares,current_underlying);
    assert_eq(fund::sub_underlying(&mut pool, 437, false), shares_burned);   
    assert_eq(fund::underlying(&pool), current_underlying - 437);
    assert_eq(fund::shares(&pool), current_shares - shares_burned);   

    let underlying_burned = math64::mul_div_up(387,current_underlying - 437, current_shares - shares_burned);
    assert_eq(fund::sub_shares(&mut pool, 387, true), underlying_burned);   
    assert_eq(fund::underlying(&pool), current_underlying - 437 - underlying_burned);
    assert_eq(fund::shares(&pool), current_shares - shares_burned - 387);  
  }
}