#[test_only]
module suitears::s_eth {
  use std::option;

  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  struct S_ETH has drop {}

  #[lint_allow(share_owned)]
  fun init(witness: S_ETH, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<S_ETH>(
            witness, 
            9, 
            b"ETH",
            b"Ether", 
            b"Ethereum Native Coin", 
            option::none(), 
            ctx
        );

      transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
      transfer::public_share_object(metadata);
  }

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(S_ETH {}, ctx);
  }
}

#[test_only]
module suitears::s_btc {
  use std::option;

  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  struct S_BTC has drop {}

  #[lint_allow(share_owned)]
  fun init(witness: S_BTC, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<S_BTC>(
            witness, 
            6, 
            b"BTC",
            b"Bitcoin", 
            b"Bitcoin Native Coin", 
            option::none(), 
            ctx
        );

      transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
      transfer::public_share_object(metadata);
  }

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(S_BTC {}, ctx);
  }
}