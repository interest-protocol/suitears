/*
* @title TypeName Utils
*
* @notice A utility library to operate on `std::type_name`. 
*/
module examples::type_name_utils {
  // === Imports === 
  
  use std::type_name::{Self, TypeName};

  // === Errors === 

  const EDifferentPackage: u64 = 0;

  // === Public Mutative Functions ===     

  /*
  * @notice Asserts that the module calling this function and passing the witness is from the same package as the collection
  */
  public fun assert_same_package(x: TypeName, y: TypeName) {
    let first_package_id = type_name::get_address(&x);

    let second_package_id = type_name::get_address(&y);

    assert!(first_package_id == second_package_id, EDifferentPackage);
  }    
}