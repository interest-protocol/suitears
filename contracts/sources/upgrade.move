// It adds a timelock before the admin can upgrade a package
module suimate::upgrade {
    use std::vector;

    use sui::event::emit;
    use sui::dynamic_field as df;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::package::{Self, UpgradeCap, UpgradeTicket, UpgradeReceipt};  

    use suimate::timelock::{Self, TimeLockCap};

    // Errors
    const EInvalidTimelock: u64 = 0;

    // Do not expose this
    struct TimeLockName has drop {}
    
    struct Package has copy, drop, store {}

    struct UpgradeWrapper has key, store {
        id: UID,
        cap: UpgradeCap,
        policy: u8,
        digest: vector<u8>,
        epochs_delay: u64
    }
    
    // * Events

    struct NewUpgradeWrapper has copy, drop {
        upgrade_cap: ID,
        wrapper: ID,
        epochs_delay: u64
    }

    struct ImmutablePackage has copy, drop {
        id: ID
    }

    struct InitUpgrade has copy, drop {
        id: ID,
        policy: u8,
        digest: vector<u8>,
        unlock_epoch: u64
    }

    struct AuthorizeUpgrade has copy, drop {
        id: ID,
        policy: u8,
        digest: vector<u8>,
        epoch: u64
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
        epochs_delay: u64,
        ctx: &mut TxContext
    ): UpgradeWrapper {
        let wrapper = UpgradeWrapper {
            id: object::new(ctx),
            cap,
            policy: 0,
            digest: vector::empty(),
            epochs_delay
        };
        emit(NewUpgradeWrapper { 
          wrapper: object::id(&wrapper), 
          upgrade_cap: object::id(&wrapper.cap), 
          epochs_delay
        });
        wrapper
    }

    public fun init_upgrade(
        cap: &mut UpgradeWrapper,
        policy: u8,
        digest: vector<u8>,
        ctx: &mut TxContext        
    ): TimeLockCap {
        let unlock_epoch = tx_context::epoch(ctx) + cap.epochs_delay;
        cap.policy = policy;
        cap.digest = digest;

        let lock = timelock::create(TimeLockName {}, unlock_epoch,  false, ctx);
        let p = package::upgrade_package(&cap.cap);

        add_package(&mut lock, p);
        
        emit(InitUpgrade { id: p, unlock_epoch, policy, digest });

        lock
    }

    public fun cancel_upgrade(cap: &mut UpgradeWrapper, lock: TimeLockCap) {
        cap.policy = 0;
        cap.digest = vector::empty();
        timelock::destroy(lock);
        emit(CancelUpgrade { id:  package::upgrade_package(&cap.cap) });
    }

    public fun authorize_upgrade(
        cap: &mut UpgradeWrapper,
        lock: TimeLockCap,
        ctx: &mut TxContext  
    ): UpgradeTicket {
        assert!(get_package(&lock) == package::upgrade_package(&cap.cap), EInvalidTimelock);
        timelock::assert_unlock_epoch_and_destroy(TimeLockName {}, lock, ctx);

        let epoch = tx_context::epoch(ctx);

        emit(AuthorizeUpgrade { id: package::upgrade_package(&cap.cap), epoch, policy: cap.policy, digest: cap.digest });
        
        package::authorize_upgrade(&mut cap.cap, cap.policy, cap.digest)
    }

    public fun commit_upgrade(cap: &mut UpgradeWrapper, receipt: UpgradeReceipt) {
        emit(CommitUpgrade { id: package::upgrade_package(&cap.cap)});
        package::commit_upgrade(&mut cap.cap, receipt);
    }
    
    // @dev Make a package immutable
    public entry fun make_package_immutable(cap: UpgradeCap) {
        emit(ImmutablePackage { id: package::upgrade_package(&cap) });
        package::make_immutable(cap);
    }



  // Private Fns

  fun add_package(lock: &mut TimeLockCap, p: ID) {
    timelock::add_extra_data(lock, Package {}, p);
  }

  fun get_package(lock: &TimeLockCap): ID {
    *timelock::borrow_extra_data(lock, Package {})
  }
}