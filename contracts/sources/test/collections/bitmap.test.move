#[test_only]
module suitears::bitmap_tests {

  use sui::tx_context;
  use sui::test_utils::assert_eq;

  use suitears::bitmap;

  const KEY_A: u256 = 7891;
  const KEY_B: u256 = 451;
  const KEY_C: u256 = 9592328;

  #[test]
  fun test_starts_empty() {
    let ctx = tx_context::dummy();
    let map = bitmap::new(&mut ctx);
    assert_eq(bitmap::get(&map, KEY_A), false);
    assert_eq(bitmap::get(&map, KEY_B), false);
    assert_eq(bitmap::get(&map, KEY_C), false);

    bitmap::destroy(map);
  }

  #[test]
  fun test_case_one() {
    let ctx = tx_context::dummy();
    let map = bitmap::new(&mut ctx);

    // Set KEY_A to true
    bitmap::set(&mut map, KEY_A);
    assert_eq(bitmap::get(&map, KEY_A), true);
    assert_eq(bitmap::get(&map, KEY_B), false);
    assert_eq(bitmap::get(&map, KEY_C), false);

    // Set KEY_A to true
    bitmap::unset(&mut map, KEY_A);
    assert_eq(bitmap::get(&map, KEY_A), false);
    assert_eq(bitmap::get(&map, KEY_B), false);
    assert_eq(bitmap::get(&map, KEY_C), false);

    // Set several consecutive keys
    bitmap::set(&mut map, KEY_A);
    bitmap::set(&mut map, KEY_A + 1);
    bitmap::set(&mut map, KEY_A + 2);
    bitmap::set(&mut map, KEY_A + 3);
    bitmap::set(&mut map, KEY_A + 4);
    assert_eq(bitmap::get(&map, KEY_A + 2), true);
    assert_eq(bitmap::get(&map, KEY_A + 4), true); 

    bitmap::unset(&mut map, KEY_A + 2);
    bitmap::unset(&mut map, KEY_A + 4);
    assert_eq(bitmap::get(&map, KEY_A), true);
    assert_eq(bitmap::get(&map, KEY_A + 1), true);
    assert_eq(bitmap::get(&map, KEY_A + 2), false);
    assert_eq(bitmap::get(&map, KEY_A + 3), true);
    assert_eq(bitmap::get(&map, KEY_A + 4), false);    

    bitmap::destroy(map);
  }

  #[test]
  fun test_case_two() {
    let ctx = tx_context::dummy();
    let map = bitmap::new(&mut ctx); 

    // adds several keys
    bitmap::set(&mut map, KEY_A);
    bitmap::set(&mut map, KEY_B);
    assert_eq(bitmap::get(&map, KEY_A), true);
    assert_eq(bitmap::get(&map, KEY_B), true);
    assert_eq(bitmap::get(&map, KEY_C), false);

    bitmap::set(&mut map, KEY_A + 1);
    bitmap::set(&mut map, KEY_A + 3);
    assert_eq(bitmap::get(&map, KEY_A), true);
    assert_eq(bitmap::get(&map, KEY_B), true);
    assert_eq(bitmap::get(&map, KEY_C), false);
    assert_eq(bitmap::get(&map, KEY_A + 1), true);
    assert_eq(bitmap::get(&map, KEY_A + 2), false);
    assert_eq(bitmap::get(&map, KEY_A + 3), true);    
    assert_eq(bitmap::get(&map, KEY_A + 4), false);

    bitmap::destroy(map);   
  }

  #[test]
  fun test_case_three() {
    let ctx = tx_context::dummy();
    let map = bitmap::new(&mut ctx); 

    // adds several keys
    bitmap::set(&mut map, KEY_A);
    assert_eq(bitmap::get(&map, KEY_A), true);
    bitmap::set(&mut map, KEY_B);
    bitmap::unset(&mut map, KEY_A);    
    assert_eq(bitmap::get(&map, KEY_A), false);
    assert_eq(bitmap::get(&map, KEY_B), true);
    assert_eq(bitmap::get(&map, KEY_C), false);    

    bitmap::set(&mut map, KEY_A);
    bitmap::set(&mut map, KEY_A + 1);
    bitmap::set(&mut map, KEY_A + 3);
    bitmap::unset(&mut map, KEY_A + 1);
    assert_eq(bitmap::get(&map, KEY_A), true);
    assert_eq(bitmap::get(&map, KEY_A + 1), false);
    assert_eq(bitmap::get(&map, KEY_A + 2), false);  
    assert_eq(bitmap::get(&map, KEY_A + 3), true);
    assert_eq(bitmap::get(&map, KEY_A + 4), false); 

    bitmap::destroy(map);     
  }

  #[test]
  fun test_case_four() {
    let ctx = tx_context::dummy();
    let map = bitmap::new(&mut ctx); 

    bitmap::set(&mut map, KEY_A);
    bitmap::set(&mut map, KEY_C);  

    bitmap::unset(&mut map, KEY_A);
    bitmap::unset(&mut map, KEY_B);

    bitmap::set(&mut map, KEY_B);

    bitmap::set(&mut map, KEY_A);
    bitmap::unset(&mut map, KEY_C);

    bitmap::set(&mut map, KEY_A);
    bitmap::set(&mut map, KEY_B);    

    bitmap::set(&mut map, KEY_C);
    bitmap::unset(&mut map, KEY_A);

    bitmap::set(&mut map, KEY_A);
    bitmap::unset(&mut map, KEY_B);

    assert_eq(bitmap::get(&map, KEY_A), true); 
    assert_eq(bitmap::get(&map, KEY_B), false); 
    assert_eq(bitmap::get(&map, KEY_C), true);    

    bitmap::destroy(map);     
  }
}