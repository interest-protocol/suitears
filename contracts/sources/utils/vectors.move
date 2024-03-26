/*
* @title Vectors
*
* @notice Utility functions for vectors.  
*
* @dev Credits to Movemate at https://github.com/pentagonxyz/movemate. 
*/
module suitears::vectors {
  // === Imports ===

  use std::vector;

  use sui::vec_set::{Self, VecSet};

  use suitears::math64::average;

  // === Errors ===  

  /// @dev When you supply vectors of different lengths to a function requiring equal-length vectors.
  const EVectorLengthMismatch: u64 = 0;

  // === Transform Functions ===    

  /*
  * @notice Transforms a vector into a `sui::vec_set::VecSet` to ensure that all values are unique. 
  *
  * @dev The order of the items remains the same.  
  *
  * @param v A vector.  
  * @return VecSet It returns a copy of the items in the array in a `sui::vec_set::VecSet`. 
  *
  * aborts-if:   
  * - There are repeated items in `v`.  
  */
  public fun to_vec_set<T: copy + drop>(v: vector<T>): VecSet<T> {
    let len = vector::length(&v);

    let i = 0;
    let set = vec_set::empty();
    while (len > i) {
      vec_set::insert(&mut set, *vector::borrow(&v, i));
      i = i + 1;
    };

    set
  }  

  // === Compare Functions ===  

  /*
  * @notice Searches a sorted `vec` and returns the first index that contains
  * a value greater or equal to `element`. If no such index exists (i.e. all
  * values in the vector are strictly less than `element`), and the vector length is returned.
  *
  * @dev Time complexity O(log n).
  * @dev `vec` is expected to be sorted in ascending order, and to contain no repeated elements. 
  *
  * @param vec The vector to be searched. 
  * @param element We check if there is a value higher than it in the vector. 
  * @return u64. The index of the member that is larger than `element`. The length is returned if no member is found.
  */
  public fun find_upper_bound(vec: vector<u64>, element: u64): u64 {
    if (vector::length(&vec) == 0) {
      return 0
    };

    let low = 0;
    let high = vector::length(&vec);

    while (low < high) {
      let mid = average(low, high);

      // Note that mid will always be strictly less than high (i.e. it will be a valid vector index)
      // because Math::average rounds down (it does integer division with truncation).
      if (*vector::borrow(&vec, mid) > element) {
        high = mid;
      } else {
        low = mid + 1;
      }
    };

    // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
    if (low > 0 && *vector::borrow(&vec, low - 1) == element) {
      low - 1
    } else {
      low
    }
  }

  /*
  * @notice Checks if `a` is smaller than `b`. E.g. x"123" < x"456". 
  *
  * @param a The first operand. 
  * @param b The second operand. 
  * @return bool. If `a` is smaller than `b`.
  *
  * aborts-if 
  * - `a` and `b` have different lengths. 
  */
  public fun lt(a: vector<u8>, b: vector<u8>): bool {
    let i = 0;
    let len = vector::length(&a);
    assert!(len == vector::length(&b), EVectorLengthMismatch);

    while (i < len) {
      let aa = *vector::borrow(&a, i);
      let bb = *vector::borrow(&b, i);
      if (aa < bb) return true;
      if (aa > bb) return false;
      i = i + 1;
    };

    false
  }

  /*
  * @notice Checks if `a` is larger than `b`. E.g. x"123" < x"456". 
  *
  * @param a The first operand. 
  * @param b The second operand. 
  * @return bool. If `a` is larger than `b`.
  *
  * aborts-if 
  * - `a` and `b` have different lengths. 
  */
  public fun gt(a: vector<u8>, b: vector<u8>): bool {
    let i = 0;
    let len = vector::length(&a);
    assert!(len == vector::length(&b), EVectorLengthMismatch);

    while (i < len) {
      let aa = *vector::borrow(&a, i);
      let bb = *vector::borrow(&b, i);
      if (aa > bb) return true;
      if (aa < bb) return false;
      i = i + 1;
    };

    false
  }

  /*
  * @notice Checks if `a` is smaller or equal to `b`. E.g. x"123" < x"456". 
  *
  * @param a The first operand. 
  * @param b The second operand. 
  * @return bool. If `a` is smaller or equal to `b`.
  *
  * aborts-if 
  * - `a` and `b` have different lengths. 
  */
  public fun lte(a: vector<u8>, b: vector<u8>): bool {
    let i = 0;
    let len = vector::length(&a);
    assert!(len == vector::length(&b), EVectorLengthMismatch);

    while (i < len) {
      let aa = *vector::borrow(&a, i);
      let bb = *vector::borrow(&b, i);
      if (aa < bb) return true;
      if (aa > bb) return false;
      i = i + 1;
    };

    true
  }

  /*
  * @notice Checks if `a` is larger or equal to `b`. E.g. x"123" < x"456". 
  *
  * @param a The first operand. 
  * @param b The second operand. 
  * @return bool. If `a` is larger or equal to `b`.
  *
  * aborts-if 
  * - `a` and `b` have different lengths. 
  */
  public fun gte(a: vector<u8>, b: vector<u8>): bool {
    let i = 0;
    let len = vector::length(&a);
    assert!(len == vector::length(&b), EVectorLengthMismatch);

    while (i < len) {
      let aa = *vector::borrow(&a, i);
      let bb = *vector::borrow(&b, i);
      if (aa > bb) return true;
      if (aa < bb) return false;
      i = i + 1;
    };

    true
  }

  // === Sorting Functions ===   

  /*
  * @notice Sorts a `a` in ascending order. E.g. [342] => [234].  
  *
  * @param a The vector to sort. 
  * @return vector<u256>. Sorted `a`.
  */
  public fun ascending_insertion_sort(a: vector<u256>): vector<u256> {
    let len = vector::length(&a);
    let i = 1;

    while (len > i) {
      let x = *vector::borrow(&a, i);
      let curr = i;
      let j = 0;

      while (len > j) {
        let y = *vector::borrow(&a, curr - 1);
        if (y < x) break;
        *vector::borrow_mut(&mut a, curr) = y;
        curr = curr - 1;
        if (curr == 0) break;
      };

      *vector::borrow_mut(&mut a, curr) = x;  
      i = i + 1;
    }; 

    a
  }  

  /*
  * @notice Sorts a `a` in descending order. E.g. [342] => [432].  
  *
  * @param a The vector to sort. 
  * @return vector<u256>. Sorted `a`.
  */
  public fun descending_insertion_sort(a: vector<u256>): vector<u256> {
    let len = vector::length(&a);
    let i = 1;

    while (len > i) {
      let x = *vector::borrow(&a, i);
      let curr = i;
      let j = 0;

      while (len > j) {
        let y = *vector::borrow(&a, curr - 1);
        if (y > x) break;
        *vector::borrow_mut(&mut a, curr) = y;
        curr = curr - 1;
        if (curr == 0) break;
      };

      *vector::borrow_mut(&mut a, curr) = x;  
      i = i + 1;
    }; 

    a
  }

  /*
  * @notice Sorts a `values`. E.g. [342] => [234].  
  *
  * @dev It mutates `values`. 
  * @dev It uses recursion. 
  * @dev Credits to https://github.com/suidouble/suidouble-liquid/blob/main/move/sources/suidouble_liquid_staker.move 
  *
  * @param values The vector to sort. 
  * @param left The smaller side of the pivot. Pass the 0.
  * @param right The larger side of the pivot. Pass the `vector::length - 1`.
  */  
  public fun quick_sort(values: &mut vector<u256>, left: u64, right: u64) {
    if (left < right) {
      let partition_index = partion(values, left, right);

      if (partition_index > 1) {
        quick_sort( values, left, partition_index -1);
      };
      quick_sort( values, partition_index + 1, right);
    }
  }

  // === Private Functions ===    

  /*
  * @notice A utility function for {quick_sort}. 
  *
  * @dev Places the pivot and smaller elements on the left and larger elements on the right.  
  *
  * @param values The vector to sort. 
  * @param left The smaller side of the pivot. 
  * @param right The larger side of the pivot. 
  */  
  fun partion(values: &mut vector<u256>, left: u64, right: u64): u64 {
    let pivot: u64 = left;
    let index: u64 = pivot + 1;
    let i: u64 = index;
    
    while (i <= right) {
      if ((*vector::borrow(values, i)) < (*vector::borrow(values, pivot))) {
        vector::swap(values, i, index);
        index = index + 1;
      };
      i = i + 1;
    };

    vector::swap(values, pivot, index -1);

    index - 1
  }
}