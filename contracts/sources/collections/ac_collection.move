// Inspired from Scallop AC Table
module suitears::ac_collection {

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  use suitears::owner::{Self, OwnerCap};

  struct AcCollection<C> has key, store {
    id: UID,
    collection: C
  }

  struct AcCollectionWitness has drop {}

  public fun create<C: store>(collection: C, ctx: &mut TxContext): (OwnerCap<AcCollectionWitness>, AcCollection<C>) {
    let cap_collection = AcCollection<C> {
      id: object::new(ctx),
      collection
    };

    (
      owner::create(AcCollectionWitness {}, vector[object::id(&cap_collection)], ctx), 
      cap_collection
    )
  }

  public fun create_with_cap<C: store>(cap: &mut OwnerCap<AcCollectionWitness>, collection: C, ctx: &mut TxContext): AcCollection<C> {
    let cap_collection = AcCollection<C> {
      id: object::new(ctx),
      collection
    };

    owner::add(AcCollectionWitness {}, cap, object::id(&cap_collection));

    cap_collection
  }

  public fun borrow<C: store>(self: &AcCollection<C>): &C {
    &self.collection
  }

  public fun borrow_mut<C: store>(cap: &OwnerCap<AcCollectionWitness>, self: &mut AcCollection<C>): &mut C {
    owner::assert_ownership(cap, object::id(self));
    &mut self.collection
  }

  public fun borrow_mut_uid<C: store>(cap: &OwnerCap<AcCollectionWitness>, self: &mut AcCollection<C>): &mut UID {
    owner::assert_ownership(cap, object::id(self));
    &mut self.id
  }

  public fun destroy_collection<C: store>(cap: &OwnerCap<AcCollectionWitness>, self: AcCollection<C>): C {
    owner::assert_ownership(cap, object::id(&self));
    let AcCollection { id, collection } = self;
    object::delete(id);
    collection
  }
}