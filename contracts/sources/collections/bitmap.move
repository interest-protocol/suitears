/*
 * @title Bitmap
 *
 * @notice Library for managing uint256 to bool mapping compactly and efficiently, provided the keys are sequential.
 *
 * @dev Credits to https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/BitMaps.sol
 *
 * @dev BitMaps pack 256 booleans across each bit of a single 256-bit slot of `uint256` type.
 * Hence booleans corresponding to 256 _sequential_ indices would only consume a single slot,
 * unlike the regular `bool` which would consume an entire slot for a single value.
 */
module suitears::bitmap {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::tx_context::TxContext;

  // === Constants ===

  // @dev The maximum u256. It is used to unflag an index. 
  const MAX_U256: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

  // === Structs ===

  struct Bitmap has key, store {
    id: UID
  }

  // === Public Create Function ===

  /*
  * @notice Creates a {Bitmap}. 
  *
  * @return Bitmap.
  */
  public fun new(ctx: &mut TxContext): Bitmap {
    Bitmap { id: object::new(ctx) }
  }

  // === Public View Function ===

  /*
  * @notice Checks if an `index` in the `map` is true or false. 
  *
  * @param self A reference to the {Bitmap}. 
  * @param index The slot to check if it is flagged. 
  * @return bool. If the `index` is true or false. 
  */
  public fun get(self: &Bitmap, index: u256): bool {
    let (key, mask) = key_mask(index);
    
    if (!bucket_exists(self, key)) return false;
    
    *df::borrow(&self.id, key) & mask != 0
  }

  // === Public Mutable Functions ===

  /*
  * @notice Sets the slot `index` to true in `self`. 
  *
  * @param self A reference to the {Bitmap}. 
  * @param index The slot we will set to true. 
  */
  public fun set(self: &mut Bitmap, index: u256) {
    let (key, mask) = key_mask(index);
    
    safe_register(self, key);   
    
    let x = df::borrow_mut<u256, u256>(&mut self.id, key);
    *x = *x | mask
  }

  /*
  * @notice Sets the slot `index` to false in `self`. 
  *
  * @param self A reference to the {Bitmap}. 
  * @param index The slot we will set to false. 
  */
  public fun unset(self: &mut Bitmap, index: u256) {
    let (key, mask) = key_mask(index);

    if (!bucket_exists(self, key)) return;

    let x = df::borrow_mut<u256, u256>(&mut self.id, key);
    *x = *x & (mask ^ MAX_U256)
  }

  // === Public Destroy Function ===

  /*
  * @notice Destroys the `self`. 
  *
  * @param self A bitmap to destroy. 
  */
  public fun destroy(self: Bitmap) {
    let Bitmap { id } = self;
    object::delete(id);
  }

  // === Private Functions ===  

  /*
  * @notice Finds the key and the mask to find the `index` in a {Bitmap}. 
  *
  * @param index A slot in the {Bitmap}. 
  * @return key. The key in the {Bitmap}.   
  * @return mask. To find the right in the {Bitmap} value. 
  */
  fun key_mask(index: u256): (u256, u256) {
    (index >> 8, 1 << ((index & 0xff) as u8)) 
  }

  /*
  * @notice Checks if the `key` is present in the `self`. 
  *
  * @param self A {Bitmap}. 
  * @param key A {Bitmap} key. 
  * @return bool. Check if the key exists in the {Bitmap}.   
  */
  fun bucket_exists(self: &Bitmap, key: u256): bool {
    df::exists_with_type<u256, u256>(&self.id, key)
  }

  /*
  * @notice Adds the `key` to `self`. 
  *
  * @param self A {Bitmap}. 
  * @param key A {Bitmap} key.  
  */
  fun safe_register(self: &mut Bitmap, key: u256) {
    if (!bucket_exists(self, key)) {
      df::add<u256, u256>(&mut self.id, key, 0);
    };
  }
}