// Inspired from Scallop Wit Table
module suitears::wit_collection {

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  struct WitCollection<phantom W, C> has key, store {
    id: UID,
    collection: C
  }

  public fun create<W: drop, C: store>(_: W, collection: C, ctx: &mut TxContext): WitCollection<W, C> {
    WitCollection {
      id: object::new(ctx),
      collection
    }
  }

  public fun borrow<W: drop, C: store>(self: &WitCollection<W, C>): &C {
    &self.collection
  }

  public fun borrow_mut<W: drop, C: store>(_: W, self: &mut WitCollection<W, C>): &mut C {
    &mut self.collection
  }

  public fun borrow_mut_uid<W: drop, C: store>(_: W, self: &mut WitCollection<W, C>): &mut UID {
    &mut self.id
  }

  public fun destroy_collection<W: drop, C: store>(self: WitCollection<W, C>): C {
    let WitCollection { id, collection } = self;
    object::delete(id);
    collection
  }
}