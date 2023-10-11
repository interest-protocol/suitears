/*
* Title - Semi Fungible Token
*
* Balance representation of a Semi Fungible Token
*/
module suimate::semi_fungible_balance {
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;

  // Errors
  const ESupplyOverFlow: u64 = 0;
  const EMismatchedSlot: u64 = 1;
  const EInvalidSplitAmount: u64 = 2;
  const EHasValue: u64 = 3;

  struct SFTSupply<phantom T> has store {
    data: Table<u256, u64>
  }

  struct SFTBalance<phantom T> has store {
    slot: u256, // Provides fungibility between the NFTs
    value: u64,
  }

  public fun slot<T>(self: &SFTBalance<T>): u256 {
    self.slot
  }

  public fun value<T>(self: &SFTBalance<T>): u64 {
    self.value
  }

  public fun supply_value<T>(s: &SFTSupply<T>, slot: u256): u64 {
    if (!table::contains(&s.data, slot)) return 0;
    *table::borrow(&s.data, slot)
  }

  public fun create_supply<T: drop>(ctx: &mut TxContext): SFTSupply<T> {
    SFTSupply { data: table::new(ctx) }
  }

  public fun increase_supply<T>(self: &mut SFTSupply<T>, slot: u256, value: u64): SFTBalance<T> {
    new_slot(self, slot);
    
    let current_supply = table::borrow_mut(&mut self.data, slot);
    assert!(value < (18446744073709551615u64 - *current_supply), ESupplyOverFlow);
    
    *current_supply = *current_supply + value;

    SFTBalance {
      slot,
      value
    }   
  }

  public fun decrease_supply<T>(self: &mut SFTSupply<T>, balance: SFTBalance<T>): u64 {
    let SFTBalance  { value, slot } = balance;
    let current_supply = table::borrow_mut(&mut self.data, slot);
    *current_supply = *current_supply - value;
    value
  }

  public fun zero<T>(slot: u256): SFTBalance<T> {
    SFTBalance { slot, value: 0 }
  }

  spec zero {
    aborts_if false;
    ensures result.value == 0;
  }

  public fun join<T>(self: &mut SFTBalance<T>, balance: SFTBalance<T>): u64 {
    let SFTBalance {slot, value } = balance;
    assert!(self.slot == slot, EMismatchedSlot);
    self.value = self.value + value;
    self.value
  }

  spec join {
    aborts_if false;
    ensures self.value == old(self.value) + balance.value;
    ensures result == self.value;
    ensures self.slot == old(self.slot);
    ensures self.slot == balance.slot;
  }

  public fun split<T>(self: &mut SFTBalance<T>, value: u64): SFTBalance<T> {
    assert!(self.value >= value, EInvalidSplitAmount);
    self.value = self.value - value;
    SFTBalance {slot: self.slot, value }
  }

  spec split {
    aborts_if self.value < value with EInvalidSplitAmount;
    ensures self.value == old(self.value) - value;
    ensures result.value == value;
    ensures self.slot == result.slot;
  }

  public fun withdraw_all<T>(self: &mut SFTBalance<T>): SFTBalance<T> {
    let value = self.value;
    split(self, value)
  }

  spec withdraw_all {
    ensures self.value == 0;
    ensures result.value == old(self.value);
  }

  public fun destroy_zero<T>(self: SFTBalance<T>) {
    assert!(self.value == 0, EHasValue);
    let SFTBalance {value: _, slot: _ } = self;
   }

  spec destroy_zero {
    aborts_if self.value != 0 with EHasValue;
  }

  fun new_slot<T>(self: &mut SFTSupply<T>, slot: u256) {
    if (table::contains(&self.data, slot)) return;

    table::add(&mut self.data, slot, 0);
  } 

  #[test_only]
  public fun create_for_testing<T>(slot: u256, value: u64): SFTBalance<T> {
    SFTBalance { slot, value }
  }

  #[test_only]
  public fun destroy_for_testing<T>(self: SFTBalance<T>): u64 {
    let SFTBalance { slot: _, value } = self;
    value
  }
}