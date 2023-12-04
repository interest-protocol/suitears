#[test_only]
module suitears::fixed_point_wad_tests {

  use sui::test_utils::assert_eq;

  use suitears::math256::pow;
  use suitears::int::{from_u256, neg_from_u256, value};
  use suitears::fixed_point_wad::{
    ln,
    exp,
    wad,
    div_up,
    mul_up,
    to_wad,
    div_down,
    mul_down,
    try_mul_up,
    try_div_up,
    try_mul_down,
    try_div_down,
  };

  const WAD: u256 = 1_000_000_000_000_000_000; // 1e18
  const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

  #[test]
  fun test_wad() {
    assert_eq(wad(), WAD);
  }

  #[test]
  fun test_try_mul_down() {
    let (pred, r) = try_mul_down(WAD * 3, WAD * 5);
    assert_eq(pred, true);
    assert_eq(r, 15 * WAD);

    let (pred, r) = try_mul_down(WAD * 3, (WAD / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 45 * WAD / 10);   

    let (pred, r) = try_mul_down(3333333333, 23234567832);
    assert_eq(pred, true);
    assert_eq(r, 77);  

   // not enough precision 
   let (pred, r) = try_mul_down(333333, 21234);
    assert_eq(pred, true);
    assert_eq(r, 0); // rounds down

    let (pred, r) = try_mul_down(0, (WAD / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 0); 

    let (pred, r) = try_mul_down(MAX_U256, MAX_U256);
    assert_eq(pred, false);
    assert_eq(r, 0);  
  }  

  #[test]
  fun test_try_mul_up() {
    let (pred, r) = try_mul_up(WAD * 3, WAD * 5);
    assert_eq(pred, true);
    assert_eq(r, 15 * WAD);

    let (pred, r) = try_mul_up(WAD * 3, (WAD / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 45 * WAD / 10); 

    let (pred, r) = try_mul_down(3333333333, 23234567832);
    assert_eq(pred, true);
    assert_eq(r, 77);  

    let (pred, r) = try_mul_up(333333, 21234);
    assert_eq(pred, true);
    assert_eq(r, 1); // rounds up

    let (pred, r) = try_mul_up(0, (WAD / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 0); 

    let (pred, r) = try_mul_up(MAX_U256, MAX_U256);
    assert_eq(pred, false);
    assert_eq(r, 0); 
  }

  #[test]
  fun test_try_div_down() {
    let (pred, r) = try_div_down(WAD * 3, WAD * 5);
    assert_eq(pred, true);
    assert_eq(r, 6 * WAD / 10);

    let (pred, r) = try_div_down(WAD * 3, (WAD / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 2 * WAD); //    

    let (pred, r) = try_div_down(7, 2);
    assert_eq(pred, true);
    assert_eq(r, 35 * WAD / 10); 

    let (pred, r) = try_div_down(0, (WAD / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 0); 

    let (pred, r) = try_div_down(333333333, 222222221);
    assert_eq(pred, true);
    assert_eq(r, 1500000006750000037); // rounds down
    
    let (pred, r) = try_div_down(1, 0);
    assert_eq(pred, false);
    assert_eq(r, 0); 

    let (pred, r) = try_div_down(MAX_U256, MAX_U256); // overflow
    assert_eq(pred, false);
    assert_eq(r, 0); 
  } 


  #[test]
  fun test_try_div_up() {
    let (pred, r) = try_div_up(WAD * 3, WAD * 5);
    assert_eq(pred, true);
    assert_eq(r, 6 * WAD / 10);

    let (pred, r) = try_div_up(WAD * 3, (WAD / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 2 * WAD); //    

    let (pred, r) = try_div_up(7, 2);
    assert_eq(pred, true);
    assert_eq(r, 35 * WAD / 10); 

    let (pred, r) = try_div_up(0, (WAD / 10) * 15);
    assert_eq(pred, true);
    assert_eq(r, 0); 

    let (pred, r) = try_div_up(333333333, 222222221);
    assert_eq(pred, true);
    assert_eq(r, 1500000006750000038); // rounds up
    
    let (pred, r) = try_div_up(1, 0);
    assert_eq(pred, false);
    assert_eq(r, 0); 

    let (pred, r) = try_div_up(MAX_U256, MAX_U256); // overflow
    assert_eq(pred, false);
    assert_eq(r, 0); 
  }

  #[test]
  fun test_mul_down() {
    assert_eq(mul_down(WAD * 3, WAD * 5), 15 * WAD);

    assert_eq(mul_up(333333333, 222222221), 1);  

    assert_eq(mul_down(333333, 21234), 0); // rounds down

    assert_eq(mul_down(0, (WAD / 10) * 15), 0); 
  }  

  #[test]
  fun test_mul_up() {
    assert_eq(mul_up(WAD * 3, WAD * 5), 15 * WAD);

    assert_eq(mul_up(WAD * 3, (WAD / 10) * 15), 45 * WAD / 10);    

    assert_eq(mul_up(333333, 21234), 1); // rounds up

    assert_eq(mul_up(0, (WAD / 10) * 15), 0); 
  }  

  #[test]
  fun test_div_down() {
    assert_eq(div_down(WAD * 3, WAD * 5), 6 * WAD / 10);

    assert_eq(div_down(WAD * 3, (WAD / 10) * 15), 2 * WAD); //    

    assert_eq(div_down(7, 2), 35 * WAD / 10); 

    assert_eq(div_down(0, (WAD / 10) * 15), 0); 

    assert_eq(div_down(333333333, 222222221), 1500000006750000037); // rounds down
  }  

  #[test]
  fun test_div_up() {
    assert_eq(div_up(WAD * 3, WAD * 5), 6 * WAD / 10);

    assert_eq(div_up(WAD * 3, (WAD / 10) * 15), 2 * WAD); //    

    assert_eq(div_up(7, 2), 35 * WAD / 10); 

    assert_eq(div_up(0, (WAD / 10) * 15), 0); 

    assert_eq(div_up(333333333, 222222221), 1500000006750000038); // rounds up
  }   

  #[test]
  fun test_to_wad() {
    assert_eq(to_wad(WAD, WAD), WAD);
    assert_eq(to_wad(2, 1), 2 * WAD);
    assert_eq(to_wad(20 * WAD, WAD * 10), 2 * WAD);
  } 

  #[test]
  fun test_exp() {
    assert_eq(value(exp(neg_from_u256(42139678854452767551))), 0);

    assert_eq(value(exp(neg_from_u256(3000000000000000000))), 49787068367863942);
    assert_eq(value(exp(neg_from_u256(2 * WAD))), 135335283236612691);
    assert_eq(value(exp(neg_from_u256(WAD))), 367879441171442321);

    assert_eq(value(exp(neg_from_u256(5 * WAD / 10))), 606530659712633423);
    assert_eq(value(exp(neg_from_u256(3 * WAD / 10))), 740818220681717866);

    assert_eq(value(exp(from_u256(0))), WAD);

    assert_eq(value(exp(from_u256(3 * WAD / 10))), 1349858807576003103);
    assert_eq(value(exp(from_u256(5 * WAD / 10))), 1648721270700128146);    

    assert_eq(value(exp(from_u256(1 * WAD))), 2718281828459045235);
    assert_eq(value(exp(from_u256(2 * WAD))), 7389056098930650227); 
    assert_eq(value(exp(from_u256(3 * WAD))), 20085536923187667741); 

    assert_eq(value(exp(from_u256(10 * WAD))), 220264657948067165169_80);  

    assert_eq(value(exp(from_u256(50 * WAD))), 5184705528587072464_148529318587763226117);   

    assert_eq(value(exp(from_u256(100 * WAD))), 268811714181613544841_34666106240937146178367581647816351662017);   

    assert_eq(value(exp(from_u256(135305999368893231588))), 578960446186580976_50144101621524338577433870140581303254786265309376407432913);    
  }

  #[test]
  fun test_ln() {
    assert_eq(value(ln(from_u256(WAD))),0);
    assert_eq(value(ln(from_u256(2718281828459045235))), 999999999999999999);
    assert_eq(value(ln(from_u256(11723640096265400935))), 2461607324344817918);

    
    assert_eq(ln(from_u256(1)), neg_from_u256(41446531673892822313));
    assert_eq(ln(from_u256(42)), neg_from_u256(37708862055609454007));
    assert_eq(ln(from_u256(10000)), neg_from_u256(32236191301916639577));     
    assert_eq(ln(from_u256(1000000000)), neg_from_u256(20723265836946411157));   

    assert_eq(value(ln(from_u256(pow(2, 255) - 1))), 135305999368893231589);  
    assert_eq(value(ln(from_u256(pow(2, 170)))), 76388489021297880288);   
    assert_eq(value(ln(from_u256(pow(2, 128)))), 47276307437780177293);                      
  }  

  #[test]
  #[expected_failure]
  fun test_div_down_overflow() {
    div_down(MAX_U256, MAX_U256); 
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
    mul_up(MAX_U256, MAX_U256);
  }

  #[test]
  #[expected_failure] 
  fun test_mul_down_overflow() {
    mul_down(MAX_U256, MAX_U256);
  }  

  #[test]
  #[expected_failure(abort_code = suitears::fixed_point_wad::EUndefined)] 
  fun test_negative_ln() {
    ln(neg_from_u256(1));
  }

  #[test]
  #[expected_failure(abort_code = suitears::fixed_point_wad::EUndefined)] 
  fun test_zero_ln() {
    ln(from_u256(0));
  }

  #[test]
  #[expected_failure(abort_code = suitears::fixed_point_wad::EOverflow)] 
  fun test_exp_overflow() {
    exp(from_u256(135305999368893231589));
  }
}