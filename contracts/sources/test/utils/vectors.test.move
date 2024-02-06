#[test_only]
module suitears::vectors_tests {  
  use std::vector;

  use sui::vec_set;
  use sui::test_utils::assert_eq;

  use suitears::vectors::{
    lt, 
    gt, 
    lte, 
    gte, 
    quick_sort,
    to_vec_set,
    find_upper_bound, 
    ascending_insertion_sort,
    descending_insertion_sort, 
  };
  
  #[test]
  fun test_find_upper_bound() {
    let vec = vector[33, 66, 99, 100, 123, 222, 233, 244];
    assert_eq(find_upper_bound(vec, 223), 6);
  }

  #[test]
  fun test_lt() {
    assert_eq(lt(x"19853428", x"19853429"), true);
    assert_eq(lt(x"32432023", x"32432323"), true);
    assert_eq(!lt(x"83975792", x"83975492"), true);
    assert_eq(!lt(x"83975492", x"83975492"), true);
  }

  #[test]
  fun test_gt() {
    assert_eq(gt(x"17432844", x"17432843"), true);
    assert_eq(gt(x"79847429", x"79847329"), true);
    assert_eq(!gt(x"19849334", x"19849354"), true);
    assert_eq(!gt(x"19849354", x"19849354"), true);
  }

  #[test]
  fun test_not_gt() {
    assert_eq(lte(x"23789179", x"23789279"), true);
    assert_eq(lte(x"23789279", x"23789279"), true);
    assert_eq(!lte(x"13258445", x"13258444"), true);
    assert_eq(!lte(x"13258454", x"13258444"), true);
  }

  #[test]
  fun test_lte() {
    assert_eq(lte(x"23789179", x"23789279"), true);
    assert_eq(lte(x"23789279", x"23789279"), true);
    assert_eq(!lte(x"13258445", x"13258444"), true);
    assert_eq(!lte(x"13258454", x"13258444"), true);
  }

  #[test]
  fun test_gte() {
    assert_eq(gte(x"14329932", x"14329832"), true);
    assert_eq(gte(x"14329832", x"14329832"), true);
    assert_eq(!gte(x"12654586", x"12654587"), true);
    assert_eq(!gte(x"12654577", x"12654587"), true);
  }

  #[test]
  fun test_descending_insertion_sort() {
    assert_eq(
      descending_insertion_sort(vector[5, 2, 9, 1, 5, 6]),
      vector[9 , 6, 5, 5, 2, 1]
    );

    assert_eq(
      descending_insertion_sort(vector[1, 2, 3, 4, 5, 6]),
      vector[6, 5, 4, 3, 2, 1]
    );

    assert_eq(
      descending_insertion_sort(vector[6, 5, 4, 3, 2, 1]),
      vector[6, 5, 4, 3, 2, 1]
    );

    assert_eq(
      descending_insertion_sort(vector[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]),
      vector[9, 6, 5, 5, 5, 4, 3, 3, 2, 1, 1]
    );

    assert_eq(
      descending_insertion_sort(vector[12, 23, 4, 5, 2, 34, 1, 43, 54, 32, 45, 6, 7, 8, 9, 10, 21, 20]),
      vector[54, 45, 43, 34, 32, 23, 21, 20, 12, 10, 9, 8, 7, 6, 5, 4, 2, 1]
    );
  }

  #[test]
  fun test_ascending_insertion_sort() {
    assert_eq(
      ascending_insertion_sort(vector[5, 2, 9, 1, 5, 6]),
      vector[1, 2, 5, 5, 6, 9]
    );

    assert_eq(
      ascending_insertion_sort(vector[1, 2, 3, 4, 5, 6]),
      vector[1, 2, 3, 4, 5, 6]
    );

    assert_eq(
      ascending_insertion_sort(vector[6, 5, 4, 3, 2, 1]),
      vector[1, 2, 3, 4, 5, 6]
    );

    assert_eq(
      ascending_insertion_sort(vector[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]),
      vector[1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 9]
    );

    assert_eq(
      ascending_insertion_sort(vector[12, 23, 4, 5, 2, 34, 1, 43, 54, 32, 45, 6, 7, 8, 9, 10, 21, 20]),
      vector[1, 2, 4, 5, 6, 7, 8, 9, 10, 12, 20, 21, 23, 32, 34, 43, 45, 54]
    );
  } 

  #[test]
  fun test_quick_sort() {
    let x = vector[12, 23, 4, 5, 2, 34, 1, 43, 54, 32, 45, 6, 7, 8, 9, 10, 21, 20];
    let len = vector::length(&x);
    quick_sort(&mut x, 0, len - 1);
    assert_eq(x, vector[1, 2, 4, 5, 6, 7, 8, 9, 10, 12, 20, 21, 23, 32, 34, 43, 45, 54]);
  

    let x = vector[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5];
    let len = vector::length(&x);
    quick_sort(&mut x, 0, len - 1);
    assert_eq(x, vector[1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 9]);

    let x = vector[6, 5, 4, 3, 2, 1];
    let len = vector::length(&x);
    quick_sort(&mut x, 0, len - 1);
    assert_eq(x, vector[1, 2, 3, 4, 5, 6]);    

    let x = vector[1, 2, 3, 4, 5, 6];
    let len = vector::length(&x);
    quick_sort(&mut x, 0, len - 1);
    assert_eq(x, vector[1, 2, 3, 4, 5, 6]);      

    let x = vector[5, 2, 9, 1, 5, 6];
    let len = vector::length(&x);
    quick_sort(&mut x, 0, len - 1);
    assert_eq(x, vector[1, 2, 5, 5, 6, 9]);      
  } 

  #[test]
  fun test_to_vec_set() {
    assert_eq(vec_set::empty<u64>(), to_vec_set<u64>(vector[]));
    assert_eq(vec_set::singleton(1), to_vec_set<u64>(vector[1]));

    let set = vec_set::empty();
    vec_set::insert(&mut set, 1);
    vec_set::insert(&mut set, 5);
    vec_set::insert(&mut set, 3);
    vec_set::insert(&mut set, 4);

    assert_eq(set, to_vec_set<u64>(vector[1,5,3,4]));
  }

  #[test]
  #[expected_failure]
  fun test_to_vec_set_duplicate() {
    assert_eq(vec_set::empty<u64>(), to_vec_set(vector[0, 0]));    
  }
}