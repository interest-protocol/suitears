/*
* @title Package PackageBox
*
* @notice Wraps a struct with the store ability to provide access control. Modules from the pre-determined address can mutate the box. 
*
* @dev Wraps a struct with the store in a `PackageBox<T>` object to allow anyone to {borrow} `T` but only the module from the assigned package can {borrow_mut}.
*/
module examples::package_box {
  // === Imports ===

  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  use examples::type_name_utils::assert_same_package;

  // === Structs ===

  struct PackageBox<T: store> has key, store {
    id: UID,
    // Wrapped `T`PackageBox<
    content: T,
    // Only modules from the same package as `package` can mutate the `PackageBox<T>`. 
    package: TypeName
  }

  // === Public Create Functions ===  

  /*
  * @notice Wraps a `content` in a `PackageBox<T>`. 
  *
  * @param cap A witness that will determine which package can have admin rights to the newly created `PackageBox<T>`. 
  * @param content An object with the store ability.
  * @return `PackageBox<T>`. The wrapped `content`.  
  */
  public fun new<T: store, Witness: drop>(_: Witness,  content: T, ctx: &mut TxContext): PackageBox<T> {
   PackageBox {
      id: object::new(ctx),
      content,
      package: type_name::get<Witness>()
    }
  }

  // === Public Access Functions ===   

  /*
  * @notice Returns an immutable reference to the `self.content`. 
  *
  * @param self A reference to the wrapped content. 
  * @return &T. An immutable reference to `T`.  
  */
  public fun borrow<T: store>(self: &PackageBox<T>): &T {
    &self.content
  }

  /*
  * @notice Returns a mutable reference to the `self.content`. 
  *
  * @param self The wrapped content. 
  * @param cap A witness created from the same  package as `self.package`.
  * @return &mut T. A mutable reference to `T`.  
  */
  public fun borrow_mut<T: store, Witness: drop>(self: &mut PackageBox<T>, _: Witness): &mut T {
    assert_same_package(self.package, type_name::get<Witness>());
    &mut self.content
  }

  /*
  * @notice Returns a mutable reference to the `self.content.id`. 
  *
  * @param self The wrapped content. 
  * @param cap A witness created from the same  package as `self.package`.
  * @return &mut UID. A mutable reference to `T` id.  
  */
  public fun borrow_mut_uid<T: store, Witness: drop>(self: &mut PackageBox<T>, _: Witness): &mut UID {
    assert_same_package(self.package, type_name::get<Witness>());
    &mut self.id
  }

  // === Public Destroy Functions ===     

  /*
  * @notice Destroys the wrapped struct `PackageBox<T>` and returns the inner `T`. 
  *
  * @param self The wrapped content. 
  * @param cap A witness created from the same  package as `self.package`.
  * @return T. The inner content.  
  */
  public fun destroy<T: store, Witness: drop>(self: PackageBox<T>, _: Witness): T {
    assert_same_package(self.package, type_name::get<Witness>());
    let PackageBox { id, content, package: _ } = self;
    object::delete(id);
    content
  }

  /*
  * @notice Drops the wrapped struct `PackageBox<T>` and `T`. 
  *
  * @param self The wrapped content. 
  * @param cap A witness created from the same  package as `self.package`.
  */
  public fun drop<T: store + drop, Witness: drop>(self: PackageBox<T>, _: Witness) {
    assert_same_package(self.package, type_name::get<Witness>());
    let PackageBox { id, content: _, package: _ } = self;
    object::delete(id);
  }  
}