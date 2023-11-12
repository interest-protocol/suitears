// It adds a timelock before the admin can upgrade a package
module suitears::upgrade {
    use std::vector;

    use sui::event::emit;
    use sui::clock::{Self, Clock};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID, ID};    
    use sui::package::{Self, UpgradeCap, UpgradeTicket, UpgradeReceipt};  

    use suitears::timelock::{Self, Timelock};

    struct UpgradeWrapper has key, store {
        id: UID,
        cap: UpgradeCap,
        policy: u8,
        digest: vector<u8>,
        time_delay: u64
    }
    
    // * Events

    struct NewUpgradeWrapper has copy, drop {
        time_delay: u64
    }

    struct InitUpgrade has copy, drop {
        policy: u8,
        digest: vector<u8>,
        unlock_timestamp: u64
    }

    struct AuthorizeUpgrade has copy, drop {
        policy: u8,
        digest: vector<u8>,
        timestamp: u64
    }

    struct CancelUpgrade has copy, drop {
        id: ID
    }

    struct CommitUpgrade has copy, drop {
        id: ID
    }

    // @dev Wrap the Upgrade Cap to add a Time Lock
    public fun wrap_it(
        cap: UpgradeCap,
        time_delay: u64,
        ctx: &mut TxContext
    ): UpgradeWrapper {
        let wrapper = UpgradeWrapper {
            id: object::new(ctx),
            cap,
            policy: 0,
            digest: vector::empty(),
            time_delay
        };
        emit(NewUpgradeWrapper { 
          time_delay
        });
        wrapper
    }

    public fun init_upgrade(
        c: &Clock,
        cap: UpgradeWrapper,
        policy: u8,
        digest: vector<u8>,
        ctx: &mut TxContext        
    ): Timelock<UpgradeWrapper> {
        let unlock_timestamp = clock::timestamp_ms(c) + cap.time_delay;
        cap.policy = policy;
        cap.digest = digest;
        
        emit(InitUpgrade { unlock_timestamp, policy, digest });

        timelock::lock(c, cap, unlock_timestamp, false, ctx)
    }

    public fun cancel_upgrade(c: &Clock, lock: Timelock<UpgradeWrapper>): UpgradeWrapper {
        let cap = timelock::unlock(c, lock);
        cap.policy = 0;
        cap.digest = vector::empty();
        emit(CancelUpgrade { id:  package::upgrade_package(&cap.cap) });
        cap
    }

    public fun authorize_upgrade(
        c: &Clock,
        lock: Timelock<UpgradeWrapper>,
    ): (UpgradeCap, UpgradeTicket) {
        let cap = timelock::unlock(c, lock);

        emit(AuthorizeUpgrade { timestamp: clock::timestamp_ms(c), policy: cap.policy, digest: cap.digest });

        let UpgradeWrapper { id, cap, policy, digest, time_delay: _ } = cap;

        object::delete(id);

        let ticket = package::authorize_upgrade(&mut cap, policy, digest);
        
        (cap, ticket)
    }

    public fun commit_upgrade(cap: &mut UpgradeCap, receipt: UpgradeReceipt) {
        emit(CommitUpgrade { id: package::upgrade_package(cap)});
        package::commit_upgrade(cap, receipt);
    }
}