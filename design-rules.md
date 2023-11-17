# Design Rules

### Suitears💧follows [Sui's framework API](https://github.com/MystenLabs/sui/tree/main/crates/sui-framework/packages/sui-framework) to facilitate integrations and contributions.

- **When applicable, CRUD functions must be called:**

  - add
  - remove
  - exists
  - contains
  - new
  - empty
  - to_object_name
  - from_object_name
  - object_name_property
  - borrow_object_name_property_name
  - borrow_mut_object_name_property_name

- **Functions that create objects must be called new.**

  ```Move
  module suitears::object {

      struct Object has key, store {
          id: UID
      }

      public fun new(ctx:&mut TxContext): Object {}

  }
  ```

- **Functions that create data structures must be called empty.**

  ```Move
  module suitears::data_structure {

      struct DataStructure has copy, drop, store {
          bits: vector<u8>
       }

      public fun empty(): DataStructure {}

  }
  ```

- **Do not emit events. Sui emits native events on object mutations.**

- **Shared objects must be created via a new function and be shared in a separate function. The share function must be named share_object_name.**

  ```Move
  module suitears::profile {

      struct Profile has key {
          id: UID
      }

      public fun new(ctx:&mut TxContext): Profile {}

      public fun share_profile(profile: Profile) {}

  }
  ```

- **Getter and view functions must follow this format object_name_property_name and it has to return a copy of the property.**

  ```Move
  module suitears::profile {

      struct Profile has key {
          id: UID,
          name: String,
          age: u8
      }

      public fun profile_name(self: &Profile): String {}

      public fun profile_age(self: &Profile): u8 {}

  }
  ```

- **Functions that return a reference must be named borrow_object_name_property_name or borrow_mut_object_name_property_name.**

  ```Move
  module suitears::profile {

      struct Profile has key {
          id: UID,
          name: String,
          age: u8
      }

      public fun borrow_profile_name(self: &Profile): &String {}

      public fun borrow_mut_profile_age(self: &mut Profile): &mut u8 {}

  }
  ```

- **Modules must be designed around one Object or Data Structure. A variant structure should have its own module to avoid complexity and bugs.**

  ```Move
  module suitears::wallet {
      struct Wallet has key, store {
          id: UID,
          amount: u64
      }
  }

  module suitears::claw_back_wallet {
      struct Wallet has key {
          id: UID,
          amount: u64
      }
  }
  ```

- **Comment functions with tags and refer to parameters name with ``.**

  - dev: An explanation to developers
  - param: It must be followed by the param name and a description
  - return: Name and type of the return
  - aborts-if: Describe the abort conditions

  &nbsp;

  ```Move
  module suitears::math {

      /**
      * @dev It divides `x` by `y` and rounds down
      * @param x The numerator in the division
      * @param y the denominator in the division
      * @return u64 The result of dividing `x` by `y`
      *
      * @aborts-if
      *   - `y` is zero
      */
      public fun div(x: u64, y: u64): u64 {
          assert!(y != 0, 0);
          x / y
      }

  }
  ```

- **Errors must be CamelCase, start with E and be descriptive.**

  ```Move
  module suitears::profile {
      // Wrong
      const INVALID_NAME: u64 = 0;

      // Correct
      const ENameHasMaxLengthOf64Chars: u64 = 0;
  }
  ```

- **Describe the properties of your structs.**

  ```Move
  module suitears::profile {
      struct Profile has key, store {
          id: UID,
          // The age of the user
          age: u8,
          // The first name of the user
          name: String
      }
  }
  ```

- **Comment the sections of your code.**

  ```Move
  module suitears::wallet {
      // === Events ===

      // === Read-only: Profile ===

      // === Mutative: Profile ===

      // === AdminCap: Parameters Management ===

      // === Test Only Functions ===
  }
  ```

- **Provide functions to delete objects. Empty objects must be destroyed with the function destroy_empty. The function drop must be used for objects that can be dropped.**

  ```Move
  module suitears::wallet {
    struct Wallet<Value> {
      id: UID,
      value: Value
    }

    public fun drop<Value: drop>(wallet: Wallet<Value>) {}

    public fun destroy_empty<Value>(wallet: Wallet<Value>) {}
  }
  ```
