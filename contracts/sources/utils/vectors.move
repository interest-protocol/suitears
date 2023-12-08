/// @title vectors
/// @notice Vector utilities.
/// @dev TODO: Fuzz testing?
/// Taken from https://github.com/pentagonxyz/movemate
module suitears::vectors {
  use std::vector;

  use suitears::math64::average;

  /// @dev When you supply vectors of different lengths to a function requiring equal-length vectors.
  /// TODO: Support variable length vectors?
  const EVectorLengthMismatch: u64 = 0;

  /// @dev Searches a sorted `vec` and returns the first index that contains
  /// a value greater or equal to `element`. If no such index exists (i.e. all
  /// values in the vector are strictly less than `element`), the vector length is
  /// returned. Time complexity O(log n).
  /// `vec` is expected to be sorted in ascending order, and to contain no
  /// repeated elements.
  public fun find_upper_bound(vec: &vector<u64>, element: u64): u64 {
    if (vector::length(vec) == 0) {
      return 0
    };

    let low = 0;
    let high = vector::length(vec);

    while (low < high) {
      let mid = average(low, high);

      // Note that mid will always be strictly less than high (i.e. it will be a valid vector index)
      // because Math::average rounds down (it does integer division with truncation).
      if (*vector::borrow(vec, mid) > element) {
        high = mid;
      } else {
        low = mid + 1;
      }
    };

    // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
    if (low > 0 && *vector::borrow(vec, low - 1) == element) {
      low - 1
    } else {
      low
    }
  }

  public fun lt(a: &vector<u8>, b: &vector<u8>): bool {
    let i = 0;
    let len = vector::length(a);
    assert!(len == vector::length(b), EVectorLengthMismatch);

    while (i < len) {
      let aa = *vector::borrow(a, i);
      let bb = *vector::borrow(b, i);
      if (aa < bb) return true;
      if (aa > bb) return false;
      i = i + 1;
    };

    false
  }

  public fun gt(a: &vector<u8>, b: &vector<u8>): bool {
    let i = 0;
    let len = vector::length(a);
    assert!(len == vector::length(b), EVectorLengthMismatch);

    while (i < len) {
      let aa = *vector::borrow(a, i);
      let bb = *vector::borrow(b, i);
      if (aa > bb) return true;
      if (aa < bb) return false;
      i = i + 1;
    };

    false
  }

  public fun lte(a: &vector<u8>, b: &vector<u8>): bool {
    let i = 0;
    let len = vector::length(a);
    assert!(len == vector::length(b), EVectorLengthMismatch);

    while (i < len) {
      let aa = *vector::borrow(a, i);
      let bb = *vector::borrow(b, i);
      if (aa < bb) return true;
      if (aa > bb) return false;
      i = i + 1;
    };

    true
  }

  public fun gte(a: &vector<u8>, b: &vector<u8>): bool {
    let i = 0;
    let len = vector::length(a);
    assert!(len == vector::length(b), EVectorLengthMismatch);

    while (i < len) {
      let aa = *vector::borrow(a, i);
      let bb = *vector::borrow(b, i);
      if (aa > bb) return true;
      if (aa < bb) return false;
      i = i + 1;
    };

    true
  }

  // Our pools will not have more than 4 tokens
  // Bubble sort is enough
  public fun ascending_insertion_sort(x: &vector<u256>): vector<u256> {
    let x = *x;
    let len = vector::length(&x) - 1;
    let i = 0;

    while (i < len) {
      let j = i;
      while (j > 0 && *vector::borrow(&x, j - 1) >  *vector::borrow(&x, j)) {
        vector::swap(&mut x, j, j - 1);
        j = j - 1;
      };

      i = i + 1;
    }; 

    x
  }  

  public fun descending_insertion_sort(x: &vector<u256>): vector<u256> {
    let a = *x;
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

  // @dev From https://github.com/suidouble/suidouble-liquid/blob/main/move/sources/suidouble_liquid_staker.move
  public fun quick_sort(values: &mut vector<u128>, left: u64, right: u64) {
    if (left < right) {
      let partition_index = partion(values, left, right);

      if (partition_index > 1) {
        quick_sort( values, left, partition_index -1);
      };
      quick_sort( values, partition_index + 1, right);
    }
  }

  spec quick_sort {
    pragma opaque;
  }

  // @dev Quick Sort Partition
  // From SuiDouble
  fun partion(values: &mut vector<u128>, left: u64, right: u64): u64 {
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