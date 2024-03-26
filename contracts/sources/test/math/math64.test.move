#[test_only]
module suitears::math64_tests {
  
  use sui::test_utils::assert_eq;

  use suitears::math64::{
    add,
    sub,
    min,
    max,
    mul,
    sum,
    pow,
    diff,
    clamp,
    div_up,
    try_add,
    try_sub,
    try_mul,
    try_mod,
    average,
    log2_up,
    sqrt_up,
    log10_up,
    div_down,
    sqrt_down,
    log2_down,
    log256_up,
    mul_div_up,
    log10_down,
    try_div_up,
    log256_down,
    try_div_down,
    mul_div_down,
    wrapping_add,
    wrapping_mul,
    wrapping_sub,
    try_mul_div_up,
    average_vector,
    try_mul_div_down,
  };  

  const MAX_U64: u64 = 18446744073709551615;
  const MIN: u64 = 1234;
  const MAX: u64 = 5678;

  #[test]
  fun test_wrapping_add() {
    assert_eq(wrapping_add(50, 75), 125);
    assert_eq(wrapping_add(0, 100), 100);  

    let x = pow(2, 17);
    let y = pow(2, 15);

    assert_eq(wrapping_add(x, y), x + y);    

    assert_eq(wrapping_add(456, 789), 1245);  
    assert_eq(wrapping_add(MAX_U64, 1), 0);   

    let x = pow(2, 63) - 1;

    assert_eq(wrapping_add(x, 100), 9223372036854775907);  
    assert_eq(wrapping_add(MAX_U64, 2), 1);  
    assert_eq(wrapping_add(MAX_U64, MAX_U64), 18446744073709551614);  
    assert_eq(wrapping_add(MAX_U64 - 5, 10), 4); 
    assert_eq(wrapping_add(MAX_U64, 0), MAX_U64);  
  }

  #[test]
  fun test_wrapping_mul() {
    assert_eq(wrapping_mul(50, 75), 3750);
    assert_eq(wrapping_mul(0, 100), 0);  

    let x = pow(2, 17);
    let y = pow(2, 15);

    assert_eq(wrapping_mul(x, y), x * y);    

    assert_eq(wrapping_mul(456, 789), 359784);  
    assert_eq(wrapping_mul(MAX_U64, 1), MAX_U64);   

    let x = pow(2, 50) - 1;

    assert_eq(wrapping_mul(x, 10), x * 10);  
    assert_eq(wrapping_mul(MAX_U64, 2), 18446744073709551614);  
    assert_eq(wrapping_mul(MAX_U64, MAX_U64), 1);  
    assert_eq(wrapping_mul(MAX_U64, 10), 18446744073709551606); 
    assert_eq(wrapping_mul(MAX_U64, 0), 0);  
  }

  #[test]
  fun test_wrapping_sub() {
    assert_eq(wrapping_sub(0, 0), 0);
    assert_eq(wrapping_sub(0, 1), MAX_U64);
    assert_eq(wrapping_sub(0, MAX_U64), 1);
    assert_eq(wrapping_sub(3, 1), 2);
    assert_eq(wrapping_sub(3, MAX_U64), 4);
  }

  #[test]
  fun test_try_add() {
    let (pred, result) = try_add(5678, 1234);
    assert_eq(pred, true);
    assert_eq(result, 5678 + 1234);

    let (pred, result) = try_add(MAX_U64, 1);
    assert_eq(pred, false);
    assert_eq(result, 0);
  }  

  #[test]
  fun test_try_sub() {
    let (pred, result) = try_sub(5678, 1234);
    assert_eq(pred, true);
    assert_eq(result, 5678 - 1234);  

    let (pred, result) = try_sub( 1234, 5678);
    assert_eq(pred, false);
    assert_eq(result, 0);      
  }

  #[test]
  fun test_try_mul() {
    let (pred, result) = try_mul(5678, 1234);
    assert_eq(pred, true);
    assert_eq(result, 5678 * 1234);    

    let (pred, result) = try_mul(5678, 0);
    assert_eq(pred, true);
    assert_eq(result, 0);        

    let (pred, result) = try_mul((MAX_U64 / 2) + 1, 2);
    assert_eq(pred, false);
    assert_eq(result, 0);        
  }

  #[test]
  fun test_try_div_down() {
    let (pred, result) = try_div_down(0, 1234);
    assert_eq(pred, true);
    assert_eq(result, 0 / 1234);   

    let (pred, result) = try_div_down(7, 2);
    assert_eq(pred, true);
    assert_eq(result, 3);  

    let (pred, result) = try_div_down(7000, 5678);
    assert_eq(pred, true);
    assert_eq(result, 7000 /5678); 

    let (pred, result) = try_div_down(7000, 0);
    assert_eq(pred, false);
    assert_eq(result, 0);     
  }

  #[test]
  fun test_try_div_up() {
    let (pred, result) = try_div_up(0, 1234);
    assert_eq(pred, true);
    assert_eq(result, 0 / 1234);   

    let (pred, result) = try_div_up(7, 2);
    assert_eq(pred, true);
    assert_eq(result, 4);  

    let (pred, result) = try_div_up(7000, 5678);
    assert_eq(pred, true);
    assert_eq(result, 2); 

    let (pred, result) = try_div_up(7000, 0);
    assert_eq(pred, false);
    assert_eq(result, 0);      
  }

  #[test]
  fun test_try_mul_div_down() {
    let (pred, result) = try_mul_div_down(10, 2, 4);
    assert_eq(pred, true);
    assert_eq(result, 5);   

    let (pred, result) = try_mul_div_down((MAX_U64 / 2) + 1, 2, 4);
    assert_eq(pred, true);
    assert_eq(result, 4611686018427387904);     

    let (pred, result) = try_mul_div_down(10, 2, 0);
    assert_eq(pred, false);
    assert_eq(result, 0);   

    let (pred, result) = try_mul_div_down(1, 7, 2);
    assert_eq(pred, true);
    assert_eq(result, 3); 

    let (pred, result) = try_mul_div_down(MAX_U64, 2, 2);
    assert_eq(pred, true);
    assert_eq(result, MAX_U64);     
  }  

  #[test]
  fun test_try_mul_div_up() {
    let (pred, result) = try_mul_div_up(10, 2, 4);
    assert_eq(pred, true);
    assert_eq(result, 5);   

    let (pred, result) = try_mul_div_up((MAX_U64 / 2) + 1, 2, 4);
    assert_eq(pred, true);
    assert_eq(result, 4611686018427387904);     

    let (pred, result) = try_mul_div_up(10, 2, 0);
    assert_eq(pred, false);
    assert_eq(result, 0);   

    let (pred, result) = try_mul_div_up(1, 7, 2);
    assert_eq(pred, true);
    assert_eq(result, 4); 
  }   

  #[test]
  fun test_mul_div_down() {
    assert_eq(mul_div_down(10, 2, 4), 5);
    assert_eq(mul_div_down(1, 7, 2), 3);
  }

  #[test]
  fun test_mul_div_up() {
    assert_eq(mul_div_up(10, 2, 4), 5);
    assert_eq(mul_div_up(1, 7, 2), 4);
  }  

  #[test]
  fun test_try_mod() {
    let (pred, result) = try_mod(284, 5678);
    assert_eq(pred, true);
    assert_eq(result, 284 % 5678); 

    let (pred, result) = try_mod(17034, 5678);
    assert_eq(pred, true);
    assert_eq(result, 17034 % 5678);   

    let (pred, result) = try_mod(5678, 0);
    assert_eq(pred, false);
    assert_eq(result, 0);    
  }

  #[test]
  fun test_max() {
    assert_eq(max(MAX, MIN), MAX);
    assert_eq(max(MIN, MAX), MAX);
  }

  #[test]
  fun test_min() {
    assert_eq(min(MAX, MIN), MIN);
    assert_eq(min(MIN, MAX), MIN);  
  }

  #[test]
  fun test_average() {
    let a = 57417;
    let b = 95431;
    assert_eq(average(a, b), (a + b) / 2);

    let a = 42304;
    let b = 84346;
    assert_eq(average(a, b), (a + b) / 2);    

    let a = 57417;
    let b = 84346;
    assert_eq(average(a, b), (a + b) / 2); 

    assert_eq(average(a, b), (a + b) / 2);          
  }

  #[test]
  fun test_clamp() {
    assert_eq(clamp(5, 1, 10), 5);
    assert_eq(clamp(0, 0, 100), 0);
    assert_eq(clamp(50, 0, 100), 50);
    assert_eq(clamp(0, 1, 10), 1);
    assert_eq(clamp(50, 100, 200), 100);
    assert_eq(clamp(250, 100, 200), 200);
    assert_eq(clamp(120, 0, 100), 100);
    assert_eq(clamp(1, 1, 10), 1);
    assert_eq(clamp(0, 0, 100), 0);
    assert_eq(clamp(200, 100, 200), 200);
  }

  #[test]
  fun test_add() {
    assert_eq(add(2, 3), 5);
  }

  #[test]
  fun testsub() {
    assert_eq(sub(3, 2), 1);
    assert_eq(sub(3, 3), 0);
  }

  #[test]
  fun test_mul() {
    assert_eq(mul(2, 3), 2 * 3);
  }

  #[test]
  fun test_div_down() {
    assert_eq(div_down(0, 2), 0);
    assert_eq(div_down(10, 5), 2);
    assert_eq(div_down(43, 13), 3);
    assert_eq(div_down(MAX_U64, 2), (1 << 63) - 1);
    assert_eq(div_down(MAX_U64, 1), MAX_U64);
  } 

  #[test]
  fun test_div_up() {
    assert_eq(div_up(0, 2), 0);
    assert_eq(div_up(10, 5), 2);
    assert_eq(div_up(43, 13), 4);
    assert_eq(div_up(MAX_U64, 2), 1 << 63);
    assert_eq(div_up(MAX_U64, 1), MAX_U64);
  }

  #[test]
  fun test_diff() {
    assert_eq(diff(0, 0), 0);
    assert_eq(diff(2, 0), 2);
    assert_eq(diff(0, 2), 2);  
    assert_eq(diff(1, 3), 2);      
    assert_eq(diff(3, 1), 2);        
  }

  #[test]
  fun test_sum() {
    assert_eq(sum(vector[1, 2, 3, 4, 5, 6]), 1 + 2 + 3 + 4 + 5 + 6);
  }    

  #[test]
  fun test_pow() {
    assert_eq(pow(10, 18), 1000000000000000000);
    assert_eq(pow(10, 1), 10);
    assert_eq(pow(10, 0), 1);   
    assert_eq(pow(5, 0), 1); 
    assert_eq(pow(0, 5), 0);    
    assert_eq(pow(3, 1), 3);  
    assert_eq(pow(1, 10), 1);  
    assert_eq(pow(2, 4), 16);   
    assert_eq(pow(2, 63), 9223372036854775808);                
  }

  #[test]
  fun test_average_vector() {
    assert_eq(average_vector(vector[]), 0);
    assert_eq(average_vector(vector[5]), 5);
    assert_eq(average_vector(vector[0, 0, 0, 0, 0]), 0);
    assert_eq(average_vector(vector[2, 4, 6, 8]), 5);    
    assert_eq(average_vector(vector[3, 3, 3, 3]), 3);  
    assert_eq(average_vector(vector[7, 12, 9, 5, 3]), 7);            
  }

  #[test]
  fun test_sqrt_down() {
    assert_eq(sqrt_down(0), 0);
    assert_eq(sqrt_down(1), 1);
    assert_eq(sqrt_down(2), 1);
    assert_eq(sqrt_down(3), 1);
    assert_eq(sqrt_down(4), 2);
    assert_eq(sqrt_down(144), 12);
    assert_eq(sqrt_down(999999), 999);
    assert_eq(sqrt_down(1000000), 1000);
    assert_eq(sqrt_down(1000001), 1000);
    assert_eq(sqrt_down(1002000), 1000);
    assert_eq(sqrt_down(1002001), 1001);
    assert_eq(sqrt_down(1002001), 1001);
    assert_eq(sqrt_down(MAX_U64), 4294967295);
  }  

  #[test]
  fun test_sqrt_up() {
    assert_eq(sqrt_up(0), 0);
    assert_eq(sqrt_up(1), 1);
    assert_eq(sqrt_up(2), 2);
    assert_eq(sqrt_up(3), 2);
    assert_eq(sqrt_up(4), 2);
    assert_eq(sqrt_up(144), 12);
    assert_eq(sqrt_up(999999), 1000);
    assert_eq(sqrt_up(1000000), 1000);
    assert_eq(sqrt_up(1000001), 1001);
    assert_eq(sqrt_up(1002000), 1001);
    assert_eq(sqrt_up(1002001), 1001);
    assert_eq(sqrt_up(1002001), 1001);
    assert_eq(sqrt_up(MAX_U64), 4294967296);
  }

  #[test]
  fun test_log2_down() {
    assert_eq(log2_down(0), 0);
    assert_eq(log2_down(1), 0);
    assert_eq(log2_down(2), 1);
    assert_eq(log2_down(3), 1);
    assert_eq(log2_down(4), 2);
    assert_eq(log2_down(5), 2);
    assert_eq(log2_down(6), 2);
    assert_eq(log2_down(7), 2);
    assert_eq(log2_down(8), 3);
    assert_eq(log2_down(9), 3);
    assert_eq(log2_down(MAX_U64), 63);
  }      

  #[test]
  fun test_log2_up() {
    assert_eq(log2_up(0), 0);
    assert_eq(log2_up(1), 0);
    assert_eq(log2_up(2), 1);
    assert_eq(log2_up(3), 2);
    assert_eq(log2_up(4), 2);
    assert_eq(log2_up(5), 3);
    assert_eq(log2_up(6), 3);
    assert_eq(log2_up(7), 3);
    assert_eq(log2_up(8), 3);
    assert_eq(log2_up(9), 4);
    assert_eq(log2_up(MAX_U64), 64);
  } 

  #[test]
  fun test_log10_down() {
    assert_eq(log10_down(0), 0);
    assert_eq(log10_down(1), 0);
    assert_eq(log10_down(2), 0);
    assert_eq(log10_down(9), 0);
    assert_eq(log10_down(10), 1);
    assert_eq(log10_down(11), 1);
    assert_eq(log10_down(99), 1);
    assert_eq(log10_down(100), 2);
    assert_eq(log10_down(101), 2);
    assert_eq(log10_down(999), 2);
    assert_eq(log10_down(1000), 3);
    assert_eq(log10_down(1001), 3);
    assert_eq(log10_down(MAX_U64), 19);
  }    
  
  #[test]
  fun test_log10_up() {
    assert_eq(log10_up(0), 0);
    assert_eq(log10_up(1), 0);
    assert_eq(log10_up(2), 1);
    assert_eq(log10_up(9), 1);
    assert_eq(log10_up(10), 1);
    assert_eq(log10_up(11), 2);
    assert_eq(log10_up(99), 2);
    assert_eq(log10_up(100), 2);
    assert_eq(log10_up(101), 3);
    assert_eq(log10_up(999), 3);
    assert_eq(log10_up(1000), 3);
    assert_eq(log10_up(1001), 4);
    assert_eq(log10_up(MAX_U64), 20);
  }     

  #[test]
  fun test_log256_down() {
    assert_eq(log256_down(0), 0);
    assert_eq(log256_down(1), 0);
    assert_eq(log256_down(2), 0);
    assert_eq(log256_down(255), 0);
    assert_eq(log256_down(256), 1);
    assert_eq(log256_down(257), 1);
    assert_eq(log256_down(65535), 1);
    assert_eq(log256_down(65536), 2);
    assert_eq(log256_down(65547), 2);
    assert_eq(log256_down(MAX_U64), 7);
  }  

  #[test]
  fun test_log256_up() {
    assert_eq(log256_up(0), 0);
    assert_eq(log256_up(1), 0);
    assert_eq(log256_up(2), 1);
    assert_eq(log256_up(255), 1);
    assert_eq(log256_up(256), 1);
    assert_eq(log256_up(257), 2);
    assert_eq(log256_up(65535), 2);
    assert_eq(log256_up(65536), 2);
    assert_eq(log256_up(65547), 3);
    assert_eq(log256_up(MAX_U64), 8);
  }       

  #[test]
  #[expected_failure] 
  fun test_div_up_zero_division() {
    div_up(1, 0);
  }

  #[test]
  #[expected_failure] 
  fun test_div_down_zero_division() {
    div_down(1, 0);
  }

  #[test]
  #[expected_failure] 
  fun test_mul_overflow() {
    mul(MAX_U64, 2);
  }  
}