/*
 * @title NFT Farm
 *
 * @notice A module that allows users to stake NFTs in a farm to earn rewards.
 * @notice This module doesn't supports floor price rule.
 *
 * @dev All times are in seconds.
 */
module suitears::nft_farm {
    use sui::event::emit;
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::table_vec::{Self, TableVec};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::transfer_policy::{TransferPolicy, TransferRequest};
    use suitears::math64;
    use suitears::math256;
    use suitears::owner::{Self, OwnerCap};

    // === Errors ===

    // @dev Thrown when the user tries to destroy an {Account} that still has a deposit in the {Farm}.
    const EAccountHasValue: u64 = 1;

    // @dev Thrown when the user tries to interact with a {Farm} that they do not own.
    const EInvalidAccount: u64 = 2;

    // @dev Thrown when the user tries to create a {Farm} that starts in the past.
    const EInvalidStartTime: u64 = 3;

    // @dev Thrown when the user tries to interact with a wrong {Kiosk}.
    const EInvalidKiosk: u64 = 4;

    // @dev Thrown when the user tries to interact with a wrong {NFT}.
    const EInvalidNFT: u64 = 5;

    // @dev To associate the {OwnerCap} with this module.
    public struct FarmWitness has drop {}

    public struct Account<phantom NFT, phantom RewardCoin> has key, store {
        id: UID,
        // The `sui::object::ID` of the farm to which this account belongs to.
        farm_id: ID,
        // The ids of the NFTs that the user has staked in the {Farm}.
        nft_ids: TableVec<ID>,
        // Amount of rewards the {Farm} has already paid the user.
        reward_debt: u256,
    }

    public struct Farm<phantom NFT, phantom RewardCoin> has key, store {
        id: UID,
        // Amount of {RewardCoin} to give to stakers per second.
        rewards_per_second: u64,
        // The timestamp in seconds that this farm will start distributing rewards.
        start_timestamp: u64,
        // Last timestamp that the farm was updated.
        last_reward_timestamp: u64,
        // Total amount of rewards per share distributed by this farm.
        accrued_rewards_per_share: u256,
        // Total nft staked in this farm.
        total_staked_nft: u64,
        // Owner cap of Kiosk.that holds {NFT}s.
        kiosk_cap: KioskOwnerCap,
        // {RewardCoin} deposited in this farm.
        balance_reward_coin: Balance<RewardCoin>,
        // The `sui::object::ID` of the {OwnerCap} that "owns" this farm.
        owned_by: ID,
    }

    // === Events ===

    public struct NewFarm<phantom NFT, phantom RewardCoin> has drop, copy {
        farm: ID,
        cap: ID,
    }

    public struct AddReward<phantom NFT, phantom RewardCoin> has drop, copy {
        farm: ID,
        value: u64,
    }

    public struct Stake<phantom NFT, phantom RewardCoin> has copy, drop {
        farm: ID,
        nft_id: ID,
        reward_amount: u64,
    }

    public struct Unstake<phantom NFT, phantom RewardCoin> has copy, drop {
        farm: ID,
        nft_id: ID,
        reward_amount: u64,
    }

    public struct Withdraw<phantom NFT, phantom RewardCoin> has copy, drop {
        farm: ID,
        reward_amount: u64,
    }

    public struct NewRewardRate<phantom NFT, phantom RewardCoin> has copy, drop {
        farm: ID,
        rate: u64,
    }

    // === Public Create Functions ===

    /// @dev Creates a new {OwnerCap} for the {Farm} module.
    ///
    /// @param ctx The `sui::tx_context::TxContext` shared object.
    ///
    /// @return The {OwnerCap} for the {Farm} module.
    public fun new_cap(ctx: &mut TxContext): OwnerCap<FarmWitness> {
        owner::new(FarmWitness {}, vector[], ctx)
    }

    #[allow(lint(share_owned))]
    /// @dev Creates a new {Farm} and associates it with the provided {OwnerCap}.
    ///
    /// @param cap The {OwnerCap} that will own the {Farm}.
    /// @param c The `sui::clock::Clock` shared object.
    /// @param rewards_per_second The amount of {RewardCoin} to give to stakers per second.
    /// @param start_timestamp The timestamp in seconds that this farm will start distributing rewards.
    /// @param ctx The `sui::tx_context::TxContext` shared object.
    ///
    /// @return The newly created {Farm}.
    ///
    /// @notice The {Farm} will start distributing rewards at the `start_timestamp`.
    ///
    /// @abort If the `start_timestamp` is in the past.
    ///
    /// @emit NewFarm The {Farm} and the {OwnerCap} that owns it.
    public fun new_farm<NFT, RewardCoin>(
        cap: &mut OwnerCap<FarmWitness>,
        c: &Clock,
        rewards_per_second: u64,
        start_timestamp: u64,
        ctx: &mut TxContext,
    ): Farm<NFT, RewardCoin> {
        assert!(start_timestamp > clock_timestamp_s(c), EInvalidStartTime);

        let (kiosk, owner_cap) = kiosk::new(ctx);
        transfer::public_share_object(kiosk);
        let cap_id = object::id(cap);

        let farm = Farm {
            id: object::new(ctx),
            start_timestamp,
            last_reward_timestamp: start_timestamp,
            rewards_per_second,
            accrued_rewards_per_share: 0,
            owned_by: cap_id,
            balance_reward_coin: balance::zero(),
            kiosk_cap: owner_cap,
            total_staked_nft: 0,
        };

        let farm_id = object::id(&farm);

        owner::add(cap, FarmWitness {}, farm_id);

        emit(NewFarm<NFT, RewardCoin> { farm: farm_id, cap: cap_id });

        farm
    }

    /// @dev Creates a new {Account} for the {Farm} module.
    ///
    /// @param self The {Farm} to which this account belongs to.
    /// @param ctx The `sui::tx_context::TxContext` shared object.
    ///
    /// @return The newly created {Account}.
    public fun new_account<NFT, RewardCoin>(
        self: &Farm<NFT, RewardCoin>,
        ctx: &mut TxContext,
    ): Account<NFT, RewardCoin> {
        Account {
            id: object::new(ctx),
            farm_id: object::id(self),
            nft_ids: table_vec::empty(ctx),
            reward_debt: 0,
        }
    }

    // === Public View Functions ===

    public fun rewards_per_second<NFT, RewardCoin>(self: &Farm<NFT, RewardCoin>): u64 {
        self.rewards_per_second
    }

    public fun start_timestamp<NFT, RewardCoin>(self: &Farm<NFT, RewardCoin>): u64 {
        self.start_timestamp
    }

    public fun last_reward_timestamp<NFT, RewardCoin>(self: &Farm<NFT, RewardCoin>): u64 {
        self.last_reward_timestamp
    }

    public fun accrued_rewards_per_share<NFT, RewardCoin>(self: &Farm<NFT, RewardCoin>): u256 {
        self.accrued_rewards_per_share
    }

    public fun balance_reward_coin<NFT, RewardCoin>(self: &Farm<NFT, RewardCoin>): u64 {
        balance::value(&self.balance_reward_coin)
    }

    public fun owned_by<NFT, RewardCoin>(self: &Farm<NFT, RewardCoin>): ID {
        self.owned_by
    }

    public fun amount<NFT, RewardCoin>(account: &Account<NFT, RewardCoin>): u64 {
        account.nft_ids.length()
    }

    public fun reward_debt<NFT, RewardCoin>(account: &Account<NFT, RewardCoin>): u256 {
        account.reward_debt
    }

    /// @dev Calculates the pending rewards for the provided {Account}.
    ///
    /// @param farm The {Farm} to which the {Account} belongs to.
    /// @param account The {Account} for which to calculate the pending rewards.
    /// @param c The `sui::clock::Clock` shared object.
    ///
    /// @return The pending rewards for the provided {Account}.
    public fun pending_rewards<NFT, RewardCoin>(
        farm: &Farm<NFT, RewardCoin>,
        account: &Account<NFT, RewardCoin>,
        c: &Clock,
    ): u64 {
        if (object::id(farm) != account.farm_id) return 0;

        let now = clock_timestamp_s(c);

        let cond = farm.total_staked_nft == 0 || farm.last_reward_timestamp >= now;

        let accrued_rewards_per_share = if (cond) {
            farm.accrued_rewards_per_share
        } else {
            calculate_accrued_rewards_per_share(
                farm.rewards_per_second,
                farm.accrued_rewards_per_share,
                farm.total_staked_nft,
                balance::value(&farm.balance_reward_coin),
                now - farm.last_reward_timestamp,
            )
        };

        calculate_pending_rewards(
            account,
            accrued_rewards_per_share,
        )
    }

    // === Public Mutative Functions ===

    /// @dev Stakes the provided {NFT} in the {Farm}.
    ///
    /// @param farm The {Farm} in which to stake the {NFT}.
    /// @param account The {Account} that will stake the {NFT}.
    /// @param policy The {TransferPolicy} to use for the {NFT}.
    /// @param farm_kiosk The {Kiosk} that holds the {NFT}s.
    /// @param nft The {NFT} to stake.
    /// @param c The `sui::clock::Clock` shared object.
    /// @param ctx The `sui::tx_context::TxContext` shared object.
    ///
    /// @return The amount of {RewardCoin} that the {Account} has staked.
    ///
    /// @abort If the {Farm} does not match the {Account}'s {Farm}.
    /// @abort If the {Farm} does not have access to the {Kiosk}.
    ///
    /// @emit Stake The {Farm} and the {NFT} that was staked.
    public fun stake<NFT: key + store, RewardCoin>(
        farm: &mut Farm<NFT, RewardCoin>,
        account: &mut Account<NFT, RewardCoin>,
        policy: &TransferPolicy<NFT>,
        farm_kiosk: &mut Kiosk,
        nft: NFT,
        c: &Clock,
        ctx: &mut TxContext,
    ): Coin<RewardCoin> {
        assert!(object::id(farm) == account.farm_id, EInvalidAccount);
        assert!(farm_kiosk.has_access(&farm.kiosk_cap), EInvalidKiosk);

        update(farm, clock_timestamp_s(c));
        let mut reward_coin = coin::zero<RewardCoin>(ctx);

        if (account.nft_ids.length() != 0) {
            let pending_reward = calculate_pending_rewards(
                account,
                farm.accrued_rewards_per_share,
            );
            let pending_reward = math64::min(pending_reward, farm.balance_reward_coin.value());
            if (pending_reward != 0) {
                reward_coin.balance_mut().join(farm.balance_reward_coin.split(pending_reward));
            }
        };

        account.nft_ids.push_back(object::id(&nft));

        emit(Stake<NFT, RewardCoin> {
            farm: object::id(farm),
            nft_id: object::id(&nft),
            reward_amount: coin::value(&reward_coin),
        });

        farm_kiosk.lock(&farm.kiosk_cap, policy, nft);

        farm.total_staked_nft = farm.total_staked_nft + 1;

        account.reward_debt = calculate_reward_debt(
            account.nft_ids.length(),
            farm.accrued_rewards_per_share,
        );

        reward_coin
    }

    /// @dev Stakes the provided {NFT} in the {Farm} using the provided {Kiosk}.
    ///
    /// @param farm The {Farm} in which to stake the {NFT}.
    /// @param account The {Account} that will stake the {NFT}.
    /// @param policy The {TransferPolicy} to use for the {NFT}.
    /// @param farm_kiosk The Farm {Kiosk} that holds the {NFT}s.
    /// @param nft_id The id of the {NFT} to stake.
    /// @param nft_kiosk The {Kiosk} that holds the {NFT}s.
    /// @param nft_kiosk_cap The {KioskOwnerCap} of the nft_kiosk.
    ///
    /// @return The amount of {RewardCoin} that the {Account} has staked and the {TransferRequest} for the {NFT}.
    ///
    /// @abort If the {Farm} does not match the {Account}'s {Farm}.
    /// @abort If the {Farm} does not have access to the {Kiosk}.
    ///
    /// @emit Stake The {Farm} and the {NFT} that was staked.
    public fun stake_kiosk<NFT: key + store, RewardCoin>(
        farm: &mut Farm<NFT, RewardCoin>,
        account: &mut Account<NFT, RewardCoin>,
        policy: &TransferPolicy<NFT>,
        farm_kiosk: &mut Kiosk,
        nft_id: ID,
        nft_kiosk: &mut Kiosk,
        nft_kiosk_cap: &KioskOwnerCap,
        c: &Clock,
        ctx: &mut TxContext,
    ): (Coin<RewardCoin>, TransferRequest<NFT>) {
        nft_kiosk.list<NFT>(nft_kiosk_cap, nft_id, 0);
        let coin = coin::zero<SUI>(ctx);
        let (nft, request) = nft_kiosk.purchase<NFT>(nft_id, coin);

        let reward_coin = stake(farm, account, policy, farm_kiosk, nft, c, ctx);

        (reward_coin, request)
    }

    /// @dev Unstakes the provided {NFT} from the {Farm}.
    ///
    /// @param farm The {Farm} from which to unstake the {NFT}.
    /// @param account The {Account} that will unstake the {NFT}.
    /// @param farm_kiosk The {Kiosk} that holds the {NFT}s.
    /// @param nft_id The id of the {NFT} to unstake.
    /// @param c The `sui::clock::Clock` shared object.
    /// @param ctx The `sui::tx_context::TxContext` shared object.
    ///
    /// @return The amount of {RewardCoin} that the {Account} has unstaked, the unstaked {NFT}, and the {TransferRequest} for the {NFT}.
    ///
    /// @abort If the {Farm} does not match the {Account}'s {Farm}.
    /// @abort If the {Account} does not have the {NFT}.
    ///
    /// @emit Unstake The {Farm} and the {NFT} that was unstaked.
    public fun unstake<NFT: key + store, RewardCoin>(
        farm: &mut Farm<NFT, RewardCoin>,
        account: &mut Account<NFT, RewardCoin>,
        farm_kiosk: &mut Kiosk,
        nft_id: ID,
        c: &Clock,
        ctx: &mut TxContext,
    ): (Coin<RewardCoin>, NFT, TransferRequest<NFT>) {
        let nft_index = find_in_table_vec(&account.nft_ids, nft_id);
        assert!(object::id(farm) == account.farm_id, EInvalidAccount);
        assert!(nft_index.is_some(), EInvalidNFT);
        update(farm, clock_timestamp_s(c));

        let pending_reward = calculate_pending_rewards(
            account,
            farm.accrued_rewards_per_share,
        );

        let mut reward_coin = coin::zero<RewardCoin>(ctx);

        if (pending_reward != 0) {
            let pending_reward = math64::min(pending_reward, farm.balance_reward_coin.value());
            reward_coin.balance_mut().join(farm.balance_reward_coin.split(pending_reward));
        };

        account.reward_debt = calculate_reward_debt(
            account.nft_ids.length(),
            farm.accrued_rewards_per_share,
        );

        emit(Unstake<NFT, RewardCoin> {
            farm: object::id(farm),
            nft_id,
            reward_amount: pending_reward,
        });

        farm_kiosk.list<NFT>(&farm.kiosk_cap, nft_id, 0);
        let coin = coin::zero<SUI>(ctx);
        let (nft, request) = farm_kiosk.purchase<NFT>(nft_id, coin);

        account.nft_ids.swap_remove(*nft_index.borrow());

        farm.total_staked_nft = farm.total_staked_nft - 1;

        (reward_coin, nft, request)
    }

    /// @dev Withdraws the pending rewards from the {Farm}.
    ///
    /// @param farm The {Farm} from which to withdraw the rewards.
    /// @param account The {Account} that will withdraw the rewards.
    /// @param c The `sui::clock::Clock` shared object.
    /// @param ctx The `sui::tx_context::TxContext` shared object.
    ///
    /// @return The amount of {RewardCoin} that the {Account} has withdrawn.
    ///
    /// @abort If the {Farm} does not match the {Account}'s {Farm}.
    public fun withdraw_rewards<NFT, RewardCoin>(
        farm: &mut Farm<NFT, RewardCoin>,
        account: &mut Account<NFT, RewardCoin>,
        c: &Clock,
        ctx: &mut TxContext,
    ): Coin<RewardCoin> {
        assert!(object::id(farm) == account.farm_id, EInvalidAccount);
        update(farm, clock_timestamp_s(c));

        let pending_reward = calculate_pending_rewards(
            account,
            farm.accrued_rewards_per_share,
        );

        let mut reward_coin = coin::zero<RewardCoin>(ctx);

        if (pending_reward != 0) {
            let pending_reward = math64::min(pending_reward, farm.balance_reward_coin.value());
            reward_coin.balance_mut().join(farm.balance_reward_coin.split(pending_reward));
        };

        account.reward_debt = calculate_reward_debt(
            account.nft_ids.length(),
            farm.accrued_rewards_per_share,
        );

        emit(Withdraw<NFT, RewardCoin> {
            farm: object::id(farm),
            reward_amount: coin::value(&reward_coin),
        });

        reward_coin
    }

    /// @dev Adds rewards to the {Farm}.
    ///
    /// @param self The {Farm} to which the rewards will be added.
    /// @param c The `sui::clock::Clock` shared object.
    /// @param reward The amount of {RewardCoin} to add to the {Farm}.
    ///
    /// @emit AddReward The {Farm} and the amount of {RewardCoin} that was added.
    public fun add_rewards<NFT, RewardCoin>(
        self: &mut Farm<NFT, RewardCoin>,
        c: &Clock,
        reward: Coin<RewardCoin>,
    ) {
        update(self, clock_timestamp_s(c));
        let farm_id = object::id(self);
        emit(AddReward<NFT, RewardCoin> { farm: farm_id, value: coin::value(&reward) });
        self.balance_reward_coin.join(reward.into_balance());
    }

    // === Public Destroy Function ===
    public fun destroy_zero_account<NFT, RewardCoin>(account: Account<NFT, RewardCoin>) {
        let Account { id, nft_ids, reward_debt: _, farm_id: _ } = account;
        assert!(nft_ids.length() == 0, EAccountHasValue);
        nft_ids.destroy_empty();
        id.delete();
    }

    // === Admin Only Functions ===

    /// @dev Updates the rewards per second for the {Farm}.
    ///
    /// @param farm The {Farm} to update.
    /// @param cap The {OwnerCap} that owns the {Farm}.
    /// @param new_rewards_per_second The new rewards per second for the {Farm}.
    /// @param c The `sui::clock::Clock` shared object.
    ///
    /// @abort If the {OwnerCap} does not own the {Farm}.
    public fun update_rewards_per_second<NFT, RewardCoin>(
        farm: &mut Farm<NFT, RewardCoin>,
        cap: &OwnerCap<FarmWitness>,
        new_rewards_per_second: u64,
        c: &Clock,
    ) {
        owner::assert_ownership(cap, object::id(farm));
        update(farm, clock_timestamp_s(c));

        farm.rewards_per_second = new_rewards_per_second;

        emit(NewRewardRate<NFT, RewardCoin> {
            farm: object::id(farm),
            rate: new_rewards_per_second,
        });
    }

    /// @dev Destroys the {Farm} and transfers the {RewardCoin} to the {Kiosk}.
    ///
    /// @param farm The {Farm} to destroy.
    /// @param cap The {OwnerCap} that owns the {Farm}.
    ///
    /// @abort If the {OwnerCap} does not own the {Farm}.
    public fun destroy_zero_farm<NFT, RewardCoin>(
        farm: Farm<NFT, RewardCoin>,
        cap: &OwnerCap<FarmWitness>,
    ) {
        owner::assert_ownership(cap, object::id(&farm));
        let Farm {
            id,
            balance_reward_coin,
            kiosk_cap,
            owned_by: _,
            rewards_per_second: _,
            start_timestamp: _,
            last_reward_timestamp: _,
            accrued_rewards_per_share: _,
            total_staked_nft: _,
        } = farm;

        id.delete();
        balance_reward_coin.destroy_zero();
        transfer::public_transfer(kiosk_cap, @0x0)
    }

    public fun borrow_mut_uid<NFT, RewardCoin>(
        farm: &mut Farm<NFT, RewardCoin>,
        cap: &OwnerCap<FarmWitness>,
    ): &mut UID {
        owner::assert_ownership(cap, object::id(farm));
        &mut farm.id
    }

    // === Private Functions ===

    /*
     * @notice It converts the timestamp from milliseconds to seconds.
     *
     * @param c The `sui::clock::Clock` shared object.
     * @return u64. The timestamp is in seconds.
     */
    fun clock_timestamp_s(c: &Clock): u64 {
        clock::timestamp_ms(c) / 1000
    }

    fun update<NFT, RewardCoin>(farm: &mut Farm<NFT, RewardCoin>, now: u64) {
        if (farm.last_reward_timestamp >= now || farm.start_timestamp > now) return;

        let prev_reward_time_stamp = farm.last_reward_timestamp;
        farm.last_reward_timestamp = now;

        if (farm.total_staked_nft == 0) return;

        let total_reward_value = balance::value(&farm.balance_reward_coin);

        farm.accrued_rewards_per_share = calculate_accrued_rewards_per_share(
            farm.rewards_per_second,
            farm.accrued_rewards_per_share,
            farm.total_staked_nft,
            total_reward_value,
            now - prev_reward_time_stamp,
        );
    }

    fun calculate_accrued_rewards_per_share(
        rewards_per_second: u64,
        last_accrued_rewards_per_share: u256,
        total_staked_nft: u64,
        total_reward_value: u64,
        timestamp_delta: u64,
    ): u256 {
        let (total_staked_nft, total_reward_value, rewards_per_second, timestamp_delta) = (
            (total_staked_nft as u256),
            (total_reward_value as u256),
            (rewards_per_second as u256),
            (timestamp_delta as u256),
        );

        let reward = math256::min(total_reward_value, rewards_per_second * timestamp_delta);

        last_accrued_rewards_per_share + ((reward) / total_staked_nft)
    }

    fun calculate_pending_rewards<NFT, RewardCoin>(
        acc: &Account<NFT, RewardCoin>,
        accrued_rewards_per_share: u256,
    ): u64 {
        (
            (
                (
                    (acc.nft_ids.length() as u256) * accrued_rewards_per_share -
                    acc.reward_debt,
                ) as u64,
            ),
        )
    }

    fun calculate_reward_debt(nft_amount: u64, accrued_rewards_per_share: u256): u256 {
        let nft_amount = nft_amount as u256;

        (nft_amount * accrued_rewards_per_share)
    }

    fun find_in_table_vec(table_vec: &TableVec<ID>, id: ID): Option<u64> {
        let mut i = 0;

        while (i < table_vec.length()) {
            if (table_vec.borrow(i) == id) {
                return option::some(i)
            };

            i = i + 1;
        };

        return option::none()
    }
}
