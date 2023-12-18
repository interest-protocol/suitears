/*
* @title Comparator. 
* 
* @notice A library to compare structs. 
* @notice All credits to https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/comparator.move 
*
* @dev BCS uses little-endian encoding for all integer types, so results might be unexpected.
*/
module suitears::comparator {
  // === Imports ===
  
  use std::bcs;
  use std::vector;

  // === Constants ===
  
  const EQUAL: u8 = 0;

  const SMALLER: u8 = 1;
  
  const GREATER: u8 = 2;

  // === Structs ===  

  struct Result has drop {
    // @dev It will hold one of the following values: {SMALLER}, {EQUAL} or {GREATER}.  
    inner: u8,
  }

  // === Public Compare Functions ===

  /*
  * @dev It checks if the `result` of {compare} is `EQUAL`.
  *
  * @param result This struct contains one of the following values: {SMALLER}, {EQUAL} or {GREATER}.
  * @return bool. True if it is `EQUAL`
  */
  public fun eq(result: &Result): bool {
    result.inner == EQUAL
  }

  /*
  * @dev It checks if the `result` of {compare} is `SMALLER`.
  *
  * @param result This struct contains one of the following values: {SMALLER}, {EQUAL} or {GREATER}.
  * @return bool. True if it is `SMALLER`.
  */
  public fun lt(result: &Result): bool {
    result.inner == SMALLER
  }

  /*
  * @dev It checks if the `result` of {compare} is `GREATER`.
  *
  * @param result This struct contains one of the following values: {SMALLER}, {EQUAL} or {GREATER}.
  * @return bool. True if it is `GREATER`.
  */
  public fun gt(result: &Result): bool {
    result.inner == GREATER
  }

  /*
  * @dev It checks if the `result` of {compare} is `SMALLER` or `EQUAL`.
  *
  * @param result This struct contains one of the following values: {SMALLER}, {EQUAL} or {GREATER}.
  * @return bool. True if it is `SMALLER` or `EQUAL`.
  */
  public fun lte(result: &Result): bool {
    result.inner == SMALLER || result.inner == EQUAL
  }

  /*
  * @dev It checks if the `result` of {compare} is `GREATER` or `EQUAL`.
  *
  * @param result This struct contains one of the following values: {SMALLER}, {EQUAL} or {GREATER}.
  * @return bool. True if it is `GREATER` or `EQUAL`.
  */
  public fun gte(result: &Result): bool {
    result.inner == GREATER || result.inner == EQUAL
  }  


  /*
  * @notice Compares two structs of type `T`. 
  *
  * @dev Performs a comparison of two types after BCS serialization.
  * @dev BCS uses little-endian encoding for all integer types, 
  * @dev so comparison between primitive integer types will not behave as expected.
  * @dev For example, 1(0x1) will be larger than 256(0x100) after BCS serialization.
  *
  * @param left A struct of type `T`.
  * @param right A struct of type `T`.
  * @return Result. A struct that contains the following values: {SMALLER}, {EQUAL} or {GREATER}.
  */   
  public fun compare<T>(left: &T, right: &T): Result {
    let left_bytes = bcs::to_bytes(left);
    let right_bytes = bcs::to_bytes(right);

    compare_u8_vector(left_bytes, right_bytes)
  }

  /*
  * @notice Compares two bytes. 
  *
  * @dev Performs a comparison of two types after BCS serialization.
  * @dev BCS uses little-endian encoding for all integer types, 
  * @dev so comparison between primitive integer types will not behave as expected.
  * @dev For example, 1(0x1) will be larger than 256(0x100) after BCS serialization.
  *
  * @param left A set of bytes.
  * @param right A struct of type `T`.
  * @return Result. A struct that contains the following values: {SMALLER}, {EQUAL} or {GREATER}.
  */ 
  public fun compare_u8_vector(left: vector<u8>, right: vector<u8>): Result {
    let left_length = vector::length(&left);
    let right_length = vector::length(&right);

    let idx = 0;

    while (idx < left_length && idx < right_length) {
    let left_byte = *vector::borrow(&left, idx);
    let right_byte = *vector::borrow(&right, idx);

    if (left_byte < right_byte) {
      return Result { inner: SMALLER }
    } else if (left_byte > right_byte) {
      return Result { inner: GREATER }
    };
      idx = idx + 1;
    };

    if (left_length < right_length) {
      Result { inner: SMALLER }
    } else if (left_length > right_length) {
      Result { inner: GREATER }
    } else {
      Result { inner: EQUAL }
    }
  }
}