#[test_only]
module suitears::test_nft {
    use sui::tx_context::sender;
    use sui::package;
    use sui::transfer_policy as policy;

    public struct TEST_NFT has drop {}
    public struct NFT has key, store {
        id: UID,
    }

    #[allow(lint(share_owned))]
    fun init(otw: TEST_NFT, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);
        let (policy, policy_cap) = policy::new<NFT>(&publisher, ctx);
        transfer::public_share_object(policy);
        transfer::public_transfer(publisher, sender(ctx));
        transfer::public_transfer(policy_cap, sender(ctx));
    }

    public fun new(ctx: &mut TxContext): NFT {
        NFT { id: object::new(ctx) }
    }

    public fun burn(nft: NFT) {
        let NFT { id } = nft;
        object::delete(id);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(TEST_NFT {}, ctx);
    }
}
