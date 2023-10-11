
/*
* Title - Semi Fungible Token
*
* Each Token is fungible within the same slot and non-fungible accross slots
*/
module suimate::semi_fungible_token {
  use std::ascii;
  use std::vector;
  use std::option::{Self, Option};
  use std::string::{String, utf8};

  use sui::url::{Self, Url};
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::types::is_one_time_witness;

  use suimate::semi_fungible_balance::{Self as balance, SFTBalance, SFTSupply};

  // Errors
  const EZeroDivision: u64 = 0;
  const EDivideIntoZero: u64 = 1;
  const EInvalidWitness: u64 = 2;

  struct SemiFungibleToken<phantom T> has key, store {
    id: UID, 
    balance: SFTBalance<T>
  }

  struct SFTMetadata<phantom T> has key, store {
    id: UID,
    decimals: u8,
    name: String,
    symbol: ascii::String,
    description: String,
    icon_url: Option<Url>,
    slot_description: String,
  }

  struct SFTTreasuryCap<phantom T> has key, store {
    id: UID,
    total_supply: SFTSupply<T>
  }

  public fun total_supply<T>(cap: &SFTTreasuryCap<T>, slot: u256): u64 {
    balance::supply_value(&cap.total_supply, slot)
  }

  public fun value<T>(self: &SemiFungibleToken<T>): u64 {
    balance::value(&self.balance)
  }

  public fun supply<T>(cap: &SFTTreasuryCap<T>): &SFTSupply<T> {
    &cap.total_supply
  }

  public fun supply_mut<T>(cap: &mut SFTTreasuryCap<T>): &mut SFTSupply<T> {
    &mut cap.total_supply
  }

  public fun slot<T>(self: &SemiFungibleToken<T>): u256 {
     balance::slot(&self.balance)
  }

  public fun balance<T>(self: &SemiFungibleToken<T>): &SFTBalance<T> {
    &self.balance
  }

  public fun balance_mut<T>(self: &mut SemiFungibleToken<T>): &mut SFTBalance<T> {
    &mut self.balance
  }

  public fun from_balance<T>(balance: SFTBalance<T>, ctx: &mut TxContext): SemiFungibleToken<T> {
    SemiFungibleToken { id: object::new(ctx), balance }
  }

  public fun into_balance<T>(self: SemiFungibleToken<T>): SFTBalance<T> {
    let SemiFungibleToken { id, balance } = self;
    object::delete(id);
    balance
  }

  public fun treasury_into_supply<T>(treasury: SFTTreasuryCap<T>): SFTSupply<T> {
    let SFTTreasuryCap { id, total_supply } = treasury;
    object::delete(id);
    total_supply
  }

  public fun take<T>(balance: &mut SFTBalance<T>, value: u64, ctx: &mut TxContext): SemiFungibleToken<T> {
    SemiFungibleToken {
      id: object::new(ctx),
      balance: balance::split(balance, value)
    }
  }

  spec take {
    let before_val = balance.value;
    let post after_val = balance.value;
    ensures after_val = before_val - value;

    let before_slot = balance.slot;
    let post after_slot = balance.slot;
    ensures after_slot = before_slot;

    aborts_if value > before_val;
    aborts_if ctx.ids_created + 1 > MAX_U64;
  }

  public fun put<T>(balance: &mut SFTBalance<T>, sft: SemiFungibleToken<T>) {
    balance::join(balance, into_balance(sft));
  }

  spec put {
   let before_val = balance.value;
   let post after_val = balance.value;
   ensures after_val = before_val + sft.balance.value;

   ensures balance.slot = sft.balance.slot;

   aborts_if before_val + sft.balance.value > MAX_U64;
  }
  
  public entry fun join<T>(self: &mut SemiFungibleToken<T>, a: SemiFungibleToken<T>) {
    let SemiFungibleToken { id, balance } = a;
    object::delete(id);
    balance::join(&mut self.balance, balance);
  }

  spec join {
    let before_val = self.balance.value;
    let post after_val = self.balance.value;
    ensures after_val == before_val + a.balance.value;
    
    aborts_if self.balance.slot != a.balance.slot;
    aborts_if before_val + c.balance.value > MAX_U64;    
  }

  public fun split<T>(self: &mut SemiFungibleToken<T>, split_amount: u64, ctx: &mut TxContext): SemiFungibleToken<T> {
    take(&mut self.balance, split_amount, ctx)
  }

  spec split {
    let before_val = self.balance.value;
    let post after_val = self.balance.value;
    ensures after_val == before_val - split_amount;
    ensures result.balance.value = split_amount;
    ensures resut.balance.slot = self.balance.slot;

    aborts_if split_amount > before_val;
    aborts_if ctx.ids_created + 1 > MAX_U64;
  }

  public fun divide_into_n<T>(self: &mut SemiFungibleToken<T>, n: u64, ctx: &mut TxContext): vector<SemiFungibleToken<T>> {
        assert!(n > 0, EZeroDivision);
        assert!(n <= value(self), EDivideIntoZero);

        let vec = vector::empty();
        let i = 0;
        let split_amount = value(self) / n;
        while ({
            spec {
                invariant i <= n-1;
                invariant self.balance.value == old(self).balance.value - (i * split_amount);
                invariant ctx.ids_created == old(ctx).ids_created + i;
            };
            i < n - 1
        }) {
            vector::push_back(&mut vec, split(self, split_amount, ctx));
            i = i + 1;
        };
        vec
  }

  spec divide_into_n {
    let before_val = self.balance.value;
    let post after_val = self.balance.value;
    let split_amount = before_val / n;
    ensures after_val == before_val - ((n - 1) * split_amount);

    aborts_if n == 0;
    aborts_if self.balance.value < n;
    aborts_if ctx.ids_created + n - 1 > MAX_U64;
  }

  public fun zero<T>(slot: u256, ctx: &mut TxContext): SemiFungibleToken<T> {    
    SemiFungibleToken {
      id: object::new(ctx),
      balance: balance::zero(slot)
    }
  }

  public fun create_sft<T: drop>(
    witness: T,
    decimals: u8,
    symbol: vector<u8>,
    name: vector<u8>,
    description: vector<u8>,
    slot_description: vector<u8>,
    icon_url: Option<Url>,
    ctx: &mut TxContext 
  ): (SFTTreasuryCap<T>, SFTMetadata<T>) {
    assert!(is_one_time_witness(&witness), EInvalidWitness);
    
    (
      SFTTreasuryCap {
        id: object::new(ctx),
        total_supply: balance::create_supply(ctx)
      },  
      SFTMetadata
        {
          id: object::new(ctx),
          decimals,
          name: utf8(name),
          symbol: ascii::string(symbol),
          description: utf8(description),
          slot_description: utf8(slot_description),
          icon_url
        }
    )    
  }

  public fun mint<T>(cap: &mut SFTTreasuryCap<T>, slot: u256, value: u64, ctx: &mut TxContext): SemiFungibleToken<T> {
    SemiFungibleToken {
      id: object::new(ctx),
      balance: mint_balance(cap, slot, value)
    }
  }

  public fun mint_balance<T>(cap: &mut SFTTreasuryCap<T>, slot: u256, value: u64): SFTBalance<T> {
    balance::increase_supply(&mut cap.total_supply, slot, value)
  }


  public fun burn<T>(cap: &mut SFTTreasuryCap<T>, token: SemiFungibleToken<T>): u64 {
    let SemiFungibleToken {id, balance } = token;
    object::delete(id);
    balance::decrease_supply(&mut cap.total_supply, balance)
  }

  public fun is_zero<T>(token: &SemiFungibleToken<T>): bool {
    balance::value(&token.balance) == 0
  }

  public fun burn_zero<T>(token: SemiFungibleToken<T>) {
    let SemiFungibleToken {id, balance } = token;
    object::delete(id);
    balance::destroy_zero(balance);
  }

  // === Update Token SFTMetadata ===

    public entry fun update_name<T>(
        _: &SFTTreasuryCap<T>, metadata: &mut SFTMetadata<T>, name: String
    ) {
        metadata.name = name;
    }

    public entry fun update_symbol<T>(
        _: &SFTTreasuryCap<T>, metadata: &mut SFTMetadata<T>, symbol: ascii::String
    ) {
        metadata.symbol = symbol;
    }

    public entry fun update_description<T>(
        _: &SFTTreasuryCap<T>, metadata: &mut SFTMetadata<T>, description: String
    ) {
        metadata.description = description;
    }

    public entry fun update_slot_description<T>(
        _: &SFTTreasuryCap<T>, metadata: &mut SFTMetadata<T>, slot_description: String
    ) {
        metadata.slot_description = slot_description;
    }

    public entry fun update_icon_url<T>(
        _: &SFTTreasuryCap<T>, metadata: &mut SFTMetadata<T>, url: ascii::String
    ) {
        metadata.icon_url = option::some(url::new_unsafe(url));
    }

    // === Get Token metadata fields for on-chain consumption ===

    public fun get_decimals<T>(
        metadata: &SFTMetadata<T>
    ): u8 {
        metadata.decimals
    }

    public fun get_name<T>(
        metadata: &SFTMetadata<T>
    ): String {
        metadata.name
    }

    public fun get_symbol<T>(
        metadata: &SFTMetadata<T>
    ): ascii::String {
        metadata.symbol
    }

    public fun get_description<T>(
        metadata: &SFTMetadata<T>
    ): String {
        metadata.description
    }

    public fun get_slot_description<T>(
        metadata: &SFTMetadata<T>
    ): String {
        metadata.slot_description
    }

    public fun get_icon_url<T>(
        metadata: &SFTMetadata<T>
    ): Option<Url> {
        metadata.icon_url
    }

  // === Test-only code ===

  #[test_only]
  public fun mint_for_testing<T>(slot: u256, value: u64, ctx: &mut TxContext): SemiFungibleToken<T> {
    SemiFungibleToken { id: object::new(ctx), balance: balance::create_for_testing(slot, value) }
  }

  #[test_only]
  public fun burn_for_testing<T>(token: SemiFungibleToken<T>): (u256, u64) {
    let SemiFungibleToken { id, balance } = token;
    object::delete(id);
    let slot = balance::slot(&balance);
    (slot, balance::destroy_for_testing(balance))
  }
}