#[test_only]
module suitears::vectors_tests {
  use std::vector;
  
  use sui::test_utils::assert_eq;

  use suitears::vectors::{lt, gt, lte, gte, find_upper_bound, descending_insertion_sort};
  
  #[test]
  fun test_find_upper_bound() {
    let vec = vector::empty<u64>();
    vector::push_back(&mut vec, 33);
    vector::push_back(&mut vec, 66);
    vector::push_back(&mut vec, 99);
    vector::push_back(&mut vec, 100);
    vector::push_back(&mut vec, 123);
    vector::push_back(&mut vec, 222);
    vector::push_back(&mut vec, 233);
    vector::push_back(&mut vec, 244);
    assert!(find_upper_bound(&vec, 223) == 6, 0);
  }

  #[test]
  fun test_lt() {
    assert!(lt(&x"19853428", &x"19853429"), 0);
    assert!(lt(&x"32432023", &x"32432323"), 1);
    assert!(!lt(&x"83975792", &x"83975492"), 2);
    assert!(!lt(&x"83975492", &x"83975492"), 3);
  }

  #[test]
  fun test_gt() {
    assert!(gt(&x"17432844", &x"17432843"), 0);
    assert!(gt(&x"79847429", &x"79847329"), 1);
    assert!(!gt(&x"19849334", &x"19849354"), 2);
    assert!(!gt(&x"19849354", &x"19849354"), 3);
  }

  #[test]
  fun test_not_gt() {
    assert!(lte(&x"23789179", &x"23789279"), 0);
    assert!(lte(&x"23789279", &x"23789279"), 1);
    assert!(!lte(&x"13258445", &x"13258444"), 2);
    assert!(!lte(&x"13258454", &x"13258444"), 3);
  }

  #[test]
  fun test_lte() {
    assert!(lte(&x"23789179", &x"23789279"), 0);
    assert!(lte(&x"23789279", &x"23789279"), 1);
    assert!(!lte(&x"13258445", &x"13258444"), 2);
    assert!(!lte(&x"13258454", &x"13258444"), 3);
  }

  #[test]
  fun test_gte() {
    assert!(gte(&x"14329932", &x"14329832"), 0);
    assert!(gte(&x"14329832", &x"14329832"), 1);
    assert!(!gte(&x"12654586", &x"12654587"), 2);
    assert!(!gte(&x"12654577", &x"12654587"), 3);
  }

  #[test]
  fun test_descending_insertion_sort() {
    assert_eq(
      descending_insertion_sort(&vector[5, 2, 9, 1, 5, 6]),
      vector[9 , 6, 5, 5, 2, 1]
    );

    assert_eq(
      descending_insertion_sort(&vector[1, 2, 3, 4, 5, 6]),
      vector[6, 5, 4, 3, 2, 1]
    );

    assert_eq(
      descending_insertion_sort(&vector[6, 5, 4, 3, 2, 1]),
      vector[6, 5, 4, 3, 2, 1]
    );

    assert_eq(
      descending_insertion_sort(&vector[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]),
      vector[9, 6, 5, 5, 5, 4, 3, 3, 2, 1, 1]
    );

    assert_eq(
      descending_insertion_sort(&vector[12, 23, 4, 5, 2, 34, 1, 43, 54, 32, 45, 6, 7, 8, 9, 10, 21, 20]),
      vector[54, 45, 43, 34, 32, 23, 21, 20, 12, 10, 9, 8, 7, 6, 5, 4, 2, 1]
    );
  }
}