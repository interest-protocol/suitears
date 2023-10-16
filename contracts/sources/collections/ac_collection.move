// Inspired from Scallop AC Table
module suitears::ac_collection {

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  use suitears::ownership::{Self, OwnershipCap};

  struct AcCollection<C> has key, store {
    id: UID,
    collection: C
  }

  struct AcCollectionWitness has drop {}

  struct AcCollectionCap has key, store {
    id: UID,
    cap: OwnershipCap<AcCollectionWitness>
  }

  public fun create<C: store>(collection: C, ctx: &mut TxContext): (AcCollectionCap, AcCollection<C>) {
    let cap_collection = AcCollection<C> {
      id: object::new(ctx),
      collection
    };

    (
      AcCollectionCap { id: object::new(ctx), cap: ownership::create(AcCollectionWitness {}, vector[object::id(&cap_collection)], ctx) }, 
      cap_collection
    )
  }

  public fun create_with_cap<C: store>(cap: &mut AcCollectionCap, collection: C, ctx: &mut TxContext): AcCollection<C> {
    let cap_collection = AcCollection<C> {
      id: object::new(ctx),
      collection
    };

    ownership::add(AcCollectionWitness {}, &mut cap.cap, object::id(&cap_collection));

    cap_collection
  }

  public fun borrow<C: store>(self: &AcCollection<C>): &C {
    &self.collection
  }

  public fun borrow_mut<C: store>(cap: &AcCollectionCap, self: &mut AcCollection<C>): &mut C {
    ownership::assert_ownership(&cap.cap, object::id(self));
    &mut self.collection
  }

  public fun borrow_mut_uid<C: store>(cap: &AcCollectionCap, self: &mut AcCollection<C>): &mut UID {
    ownership::assert_ownership(&cap.cap, object::id(self));
    &mut self.id
  }

  public fun destroy_cap(cap: AcCollectionCap) {
    let AcCollectionCap { id, cap } = cap;
    ownership::destroy(cap);
    object::delete(id);
  }

  public fun destroy_collection<C: store>(self: AcCollection<C>): C {
    let AcCollection { id, collection } = self;
    object::delete(id);
    collection
  }
}