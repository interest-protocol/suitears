// Inspired from Scallop
module suitears::ownership {
  use std::vector;

  use sui::object::{Self, UID, ID};
  use sui::tx_context::TxContext;

  const ENotAllowed: u64 = 0;

  struct OwnershipCap<phantom T> has key, store {
    id: UID,
    of: vector<ID>
  }

  public fun create<T: drop>(_: T, of: vector<ID>, ctx: &mut TxContext): OwnershipCap<T> {
    OwnershipCap {
      id: object::new(ctx),
      of
    }
  }

  public fun owns<T: drop>(self: &OwnershipCap<T>, x: ID): bool {
    vector::contains(&self.of, &x)
  }

  public fun view<T: drop>(self: &OwnershipCap<T>): &vector<ID> {
    &self.of
  }

  public fun assert_ownership<T: drop>(self: &OwnershipCap<T>, x: ID) {
    assert!(owns(self, x), ENotAllowed);
  }

  public fun remove<T: drop>(_: T, self: &mut OwnershipCap<T>, x: ID) {
    let (present, i) = vector::index_of(&self.of, &x);
    if (!present) return;
    vector::remove(&mut self.of, i);
  }

  public fun add<T: drop>(_: T, self: &mut OwnershipCap<T>, x: ID) {
    if (vector::contains(&self.of, &x)) return;
    vector::push_back(&mut self.of, x);
  }

  public fun destroy<T: drop>(self: OwnershipCap<T>) {
    let  OwnershipCap { id, of: _ } = self; 
    object::delete(id);
  }

  public fun destroy_empty<T: drop>(self: OwnershipCap<T>) {
    let  OwnershipCap { id, of} = self; 
    object::delete(id);
    vector::destroy_empty(of);
  }
}