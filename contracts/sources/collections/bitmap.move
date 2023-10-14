module suitears::bitmap {

  use sui::bcs;
  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::tx_context::TxContext;

  const MAX_U256: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

  struct Bitmap has key, store {
    id: UID
  }

  public fun new(ctx: &mut TxContext): Bitmap {
    Bitmap { id: object::new(ctx) }
  }

  public fun get(map: &Bitmap, index: u256): bool {
    let (key, mask) = key_mask(index);
    
    if (!bucket_exists(map, key)) return false;
    
    *df::borrow(&map.id, key) & mask != 0
  }

  public fun set(map: &mut Bitmap, index: u256) {
    let (key, mask) = key_mask(index);
    
    safe_register(map, key);   
    
    let x = df::borrow_mut<vector<u8>, u256>(&mut map.id, key);
    *x = *x | mask
  }

  public fun unset(map: &mut Bitmap, index: u256) {
    let (key, mask) = key_mask(index);

    if (!bucket_exists(map, key)) return;

    let x = df::borrow_mut<vector<u8>, u256>(&mut map.id, key);
    *x = *x & (mask ^ MAX_U256)
  }

  fun key_mask(index: u256): (vector<u8>, u256) {
    (bcs::to_bytes(&(index >> 8)), 1 << ((index & 0xff) as u8)) 
  }

  fun bucket_exists(map: &Bitmap, key: vector<u8>): bool {
    df::exists_with_type<vector<u8>, u256>(&map.id, key)
  }

  fun safe_register(map: &mut Bitmap, key: vector<u8>) {
    if (!bucket_exists(map, key)) {
      df::add(&mut map.id, key, 0);
    };
  }
}