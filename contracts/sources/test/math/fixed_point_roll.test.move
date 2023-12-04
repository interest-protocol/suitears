#[test_only]
module suitears::fixed_point_roll_tests {

  use sui::test_utils::assert_eq;

  use suitears::fixed_point_roll::{
    roll,
    div_up,
    mul_up,
    to_roll,
    div_down,
    mul_down,
    try_mul_up,
    try_div_up,
    try_mul_down,
    try_div_down,
  };

  const ROLL: u64 = 1_000_000_000; 
  const MAX_U64: u64 = 18446744073709551615;

  #[test]
  fun test_roll() {
    assert_eq(roll(), ROLL);
  }

  #[test]
  fun test_try_mul_down() {
    let (pred, r) = try_mul_down(ROLL * 3, ROLL * 5);
    assert_eq(pred, true);
    assert_eq(r, 15 * ROLL);

    let (pred, r) = try_mul_down(ROLL * 3, (ROLL / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 4500000000); //    

    let (pred, r) = try_mul_down(333333, 21234);
    assert_eq(pred, true);
    assert_eq(r, 7); // rounds down

    let (pred, r) = try_mul_down(0, (ROLL / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 0); 

    let (pred, r) = try_mul_down(MAX_U64, MAX_U64);
    assert_eq(pred, false);
    assert_eq(r, 0);  
  }

  #[test]
  fun test_try_mul_up() {
    let (pred, r) = try_mul_up(ROLL * 3, ROLL * 5);
    assert_eq(pred, true);
    assert_eq(r, 15 * ROLL);

    let (pred, r) = try_mul_up(ROLL * 3, (ROLL / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 4500000000); //    

    let (pred, r) = try_mul_up(333333, 21234);
    assert_eq(pred, true);
    assert_eq(r, 8); // rounds up

    let (pred, r) = try_mul_up(0, (ROLL / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 0); 

    let (pred, r) = try_mul_up(MAX_U64, MAX_U64);
    assert_eq(pred, false);
    assert_eq(r, 0); 
  }

  #[test]
  fun test_try_div_down() {
    let (pred, r) = try_div_down(ROLL * 3, ROLL * 5);
    assert_eq(pred, true);
    assert_eq(r, 600000000);

    let (pred, r) = try_div_down(ROLL * 3, (ROLL / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 2 * ROLL); //    

    let (pred, r) = try_div_down(7, 2);
    assert_eq(pred, true);
    assert_eq(r, 3500000000); 

    let (pred, r) = try_div_down(0, (ROLL / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 0); 

    let (pred, r) = try_div_down(333333333, 222222221);
    assert_eq(pred, true);
    assert_eq(r, 1500000006); // rounds down
    
    let (pred, r) = try_div_down(1, 0);
    assert_eq(pred, false);
    assert_eq(r, 0); 

    let (pred, r) = try_div_down(MAX_U64, MAX_U64);
    assert_eq(pred, true);
    assert_eq(r, ROLL); 
  }  

  #[test]
  fun test_try_div_up() {
    let (pred, r) = try_div_up(ROLL * 3, ROLL * 5);
    assert_eq(pred, true);
    assert_eq(r, 600000000);

    let (pred, r) = try_div_up(ROLL * 3, (ROLL / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 2 * ROLL);    

    let (pred, r) = try_div_up(7, 2);
    assert_eq(pred, true);
    assert_eq(r, 3500000000); 

    let (pred, r) = try_div_up(0, (ROLL / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 0); 

    let (pred, r) = try_div_up(333333333, 222222221);
    assert_eq(pred, true);
    assert_eq(r, 1500000007); // rounds up 
    
    let (pred, r) = try_div_up(1, 0);
    assert_eq(pred, false);
    assert_eq(r, 0); 

    let (pred, r) = try_div_up(MAX_U64, MAX_U64);
    assert_eq(pred, true);
    assert_eq(r, ROLL); 
  }

  #[test]
  fun test_mul_down() {
    assert_eq(mul_down(ROLL * 3, ROLL * 5), 15 * ROLL);

    assert_eq(mul_down(ROLL * 3, (ROLL / 10) * 15), 4500000000); //    

    assert_eq(mul_down(333333, 21234), 7); // rounds down

    assert_eq(mul_down(0, (ROLL / 10) * 15), 0); 
  }  

  #[test]
  fun test_mul_up() {
    assert_eq(mul_up(ROLL * 3, ROLL * 5), 15 * ROLL);

    assert_eq(mul_up(ROLL * 3, (ROLL / 10) * 15), 4500000000); //    

    assert_eq(mul_up(333333, 21234), 8); // rounds up

    assert_eq(mul_up(0, (ROLL / 10) * 15), 0); 
  }  

  #[test]
  fun test_div_down() {
    assert_eq(div_down(ROLL * 3, ROLL * 5), 600000000);

    assert_eq(div_down(ROLL * 3, (ROLL / 10) * 15), 2 * ROLL); //    

    assert_eq(div_down(7, 2), 3500000000); 

    assert_eq(div_down(0, (ROLL / 10) * 15), 0); 

    assert_eq(div_down(333333333, 222222221), 1500000006); // rounds down

    assert_eq(div_down(MAX_U64, MAX_U64), ROLL); 
  }  

  #[test]
  fun test_div_up() {
    assert_eq(div_up(ROLL * 3, ROLL * 5), 600000000);

    assert_eq(div_up(ROLL * 3, (ROLL / 10) * 15), 2 * ROLL); //    

    assert_eq(div_up(7, 2), 3500000000); 

    assert_eq(div_up(0, (ROLL / 10) * 15), 0); 

    assert_eq(div_up(333333333, 222222221), 1500000007); // rounds down

    assert_eq(div_up(MAX_U64, MAX_U64), ROLL); 
  } 

  #[test]
  fun test_to_roll() {
    assert_eq(to_roll(ROLL, ROLL), ROLL);
    assert_eq(to_roll(2, 1), 2 * ROLL);
    assert_eq(to_roll(20 * ROLL, ROLL * 10), 2 * ROLL);
  }

  #[test]
  #[expected_failure] 
  fun test_div_down_zero_division() {
    div_down(1, 0);
  }      

  #[test]
  #[expected_failure] 
  fun test_div_up_zero_division() {
    div_up(1, 0);
  }  

  #[test]
  #[expected_failure] 
  fun test_mul_up_overflow() {
    mul_up(MAX_U64, MAX_U64);
  }

  #[test]
  #[expected_failure] 
  fun test_mul_down_overflow() {
    mul_down(MAX_U64, MAX_U64);
  }
}