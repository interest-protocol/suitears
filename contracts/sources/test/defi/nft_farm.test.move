#[test_only]
module suitears::nft_farm_tests {
    use sui::clock;
    use sui::sui::SUI;
    use sui::kiosk::Kiosk;
    use sui::transfer_policy::{Self, TransferPolicy};
    use sui::test_utils::assert_eq;
    use sui::coin::{burn_for_testing, mint_for_testing};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

    use suitears::owner::{Self, OwnerCap};
    use suitears::test_utils::{people, scenario};
    use suitears::nft_farm::{Self, Farm, FarmWitness, Account};
    use suitears::test_nft::{Self, NFT};

    const START_TIME: u64 = 10;
    const REWARDS_PER_SECOND: u64 = 10_000_000_000;

    #[test]
    fun test_stake() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let mut c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let nft = test_nft::new(ctx(test));

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut account,
                &policy,
                &mut kiosk,
                nft,
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let nft = test_nft::new(ctx(test));

            // 5 seconds of rewards
            clock::increment_for_testing(&mut c, 5000 + 10_000);

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut account,
                &policy,
                &mut kiosk,
                nft,
                &c,
                ctx(test),
            );

            let accrued_rewards_per_share = nft_farm::accrued_rewards_per_share(&farm);

            assert_eq(burn_for_testing(reward_coin), 5 * REWARDS_PER_SECOND);
            assert_eq(nft_farm::amount(&account), 2);
            assert_eq(
                nft_farm::reward_debt(&account),
                accrued_rewards_per_share * 2,
            );
            assert_eq(nft_farm::last_reward_timestamp(&farm), 15_000 / 1000);

            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let nft = test_nft::new(ctx(test));

            // 15 more seconds of rewards
            clock::increment_for_testing(&mut c, 15_000);

            let rewards_debt = nft_farm::reward_debt(&account);
            let pending_rewards = nft_farm::pending_rewards(&farm, &account, &c);

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut account,
                &policy,
                &mut kiosk,
                nft,
                &c,
                ctx(test),
            );

            let accrued_rewards_per_share = nft_farm::accrued_rewards_per_share(&farm);

            assert_eq(
                (burn_for_testing(reward_coin) as u256),
                ((2 * accrued_rewards_per_share)) - rewards_debt,
            );
            assert_eq(
                (pending_rewards as u256),
                ((2 * accrued_rewards_per_share)) - rewards_debt,
            );
            assert_eq(nft_farm::amount(&account), 3);
            assert_eq(
                nft_farm::reward_debt(&account),
                (accrued_rewards_per_share * 3),
            );
            assert_eq(nft_farm::last_reward_timestamp(&farm), (15_000 * 2) / 1000);

            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };

        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    fun test_unstake() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let mut c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
        let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
        let mut kiosk = test::take_shared<Kiosk>(test);
        let policy = test::take_shared<TransferPolicy<NFT>>(test);

        let nft = test_nft::new(ctx(test));
        let nft_id = object::id(&nft);

        let reward_coin = nft_farm::stake(
            &mut farm,
            &mut account,
            &policy,
            &mut kiosk,
            nft,
            &c,
            ctx(test),
        );

        burn_for_testing(reward_coin);
        test::return_to_sender(test, account);
        test::return_shared(farm);
        test::return_shared(kiosk);
        test::return_shared(policy);

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            // 5 seconds of rewards
            clock::increment_for_testing(&mut c, 5000 + 10_000);

            let pending_rewards = nft_farm::pending_rewards(&farm, &account, &c);

            let (reward_coin, nft, request) = nft_farm::unstake(
                &mut farm,
                &mut account,
                &mut kiosk,
                nft_id,
                &c,
                ctx(test),
            );

            let accrued_rewards_per_share = nft_farm::accrued_rewards_per_share(&farm);

            assert_eq(burn_for_testing(reward_coin), 5 * REWARDS_PER_SECOND);
            assert_eq(pending_rewards, 5 * REWARDS_PER_SECOND);
            assert_eq(nft_farm::amount(&account), 0);
            assert_eq(
                nft_farm::reward_debt(&account),
                (5 * REWARDS_PER_SECOND) as u256,
            );
            assert_eq(nft_farm::last_reward_timestamp(&farm), 15_000 / 1000);
            assert_eq(
                accrued_rewards_per_share,
                (5 * REWARDS_PER_SECOND) as u256,
            );

            transfer_policy::confirm_request(&policy, request);
            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
            test_nft::burn(nft);
        };

        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    fun test_withdraw_rewards() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let mut c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let nft = test_nft::new(ctx(test));

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut account,
                &policy,
                &mut kiosk,
                nft,
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);

            // 5 seconds of rewards
            clock::increment_for_testing(&mut c, 5000 + 10_000);

            let pending_rewards = nft_farm::pending_rewards(&farm, &account, &c);

            let reward_coin = nft_farm::withdraw_rewards(
                &mut farm,
                &mut account,
                &c,
                ctx(test),
            );

            let accrued_rewards_per_share = nft_farm::accrued_rewards_per_share(&farm);

            assert_eq(burn_for_testing(reward_coin), 5 * REWARDS_PER_SECOND);
            assert_eq(pending_rewards, 5 * REWARDS_PER_SECOND);
            assert_eq(nft_farm::amount(&account), 1);
            assert_eq(
                nft_farm::reward_debt(&account),
                (5 * REWARDS_PER_SECOND) as u256,
            );
            assert_eq(nft_farm::last_reward_timestamp(&farm), 15_000 / 1000);
            assert_eq(
                accrued_rewards_per_share,
                (5 * REWARDS_PER_SECOND) as u256,
            );

            test::return_to_sender(test, account);
            test::return_shared(farm);
        };

        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    // Stake -> Unstake -> Stake -> Withdraw Rewards -> Unstake
    fun test_end_to_end() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let mut c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
        let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
        let mut kiosk = test::take_shared<Kiosk>(test);
        let policy = test::take_shared<TransferPolicy<NFT>>(test);

        let nft = test_nft::new(ctx(test));
        let nft_id = object::id(&nft);

        let reward_coin = nft_farm::stake(
            &mut farm,
            &mut account,
            &policy,
            &mut kiosk,
            nft,
            &c,
            ctx(test),
        );

        burn_for_testing(reward_coin);
        test::return_to_sender(test, account);
        test::return_shared(farm);
        test::return_shared(kiosk);
        test::return_shared(policy);

        // 5 seconds of rewards
        clock::increment_for_testing(&mut c, 5000 + 10_000);

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let pending_rewards = nft_farm::pending_rewards(&farm, &account, &c);

            let (reward_coin, nft, request) = nft_farm::unstake(
                &mut farm,
                &mut account,
                &mut kiosk,
                nft_id,
                &c,
                ctx(test),
            );

            let accrued_rewards_per_share = nft_farm::accrued_rewards_per_share(&farm);

            assert_eq(burn_for_testing(reward_coin), 5 * REWARDS_PER_SECOND);
            assert_eq(pending_rewards, 5 * REWARDS_PER_SECOND);
            assert_eq(nft_farm::amount(&account), 0);
            assert_eq(
                nft_farm::reward_debt(&account),
                (5 * REWARDS_PER_SECOND) as u256,
            );
            assert_eq(nft_farm::last_reward_timestamp(&farm), 15_000 / 1000);
            assert_eq(
                accrued_rewards_per_share,
                (5 * REWARDS_PER_SECOND) as u256,
            );

            transfer_policy::confirm_request(&policy, request);
            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
            test_nft::burn(nft);
        };

        // 10 more seconds of rewards

        clock::increment_for_testing(&mut c, 10_000);

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let nft = test_nft::new(ctx(test));

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut account,
                &policy,
                &mut kiosk,
                nft,
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };

        // 15 more seconds of rewards

        clock::increment_for_testing(&mut c, 15_000);

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);

            let pending_rewards = nft_farm::pending_rewards(&farm, &account, &c);

            let reward_coin = nft_farm::withdraw_rewards(
                &mut farm,
                &mut account,
                &c,
                ctx(test),
            );

            let accrued_rewards_per_share = nft_farm::accrued_rewards_per_share(&farm);

            assert_eq(burn_for_testing(reward_coin), 15 * REWARDS_PER_SECOND);
            assert_eq(pending_rewards, 15 * REWARDS_PER_SECOND);
            assert_eq(nft_farm::amount(&account), 1);
            assert_eq(
                nft_farm::reward_debt(&account),
                (20 * REWARDS_PER_SECOND) as u256,
            );
            assert_eq(nft_farm::last_reward_timestamp(&farm), 40);
            assert_eq(
                accrued_rewards_per_share,
                (20 * REWARDS_PER_SECOND) as u256,
            );

            test::return_to_sender(test, account);
            test::return_shared(farm);
        };

        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[lint_allow(share_owned)]
    fun test_no_rewards() {
        let mut scenario = scenario();
        let (alice, bob) = people();

        let test = &mut scenario;

        let mut c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            test_nft::test_init(ctx(test));
        };

        next_tx(test, alice);
        {
            let mut cap = nft_farm::new_cap(ctx(test));
            let mut farm = nft_farm::new_farm<NFT, SUI>(
                &mut cap,
                &c,
                REWARDS_PER_SECOND,
                1,
                ctx(test),
            );

            nft_farm::add_rewards(
                &mut farm,
                &c,
                mint_for_testing(10_000_000_000 * 5, ctx(test)),
            );

            // send accounts to people
            transfer::public_transfer(nft_farm::new_account(&farm, ctx(test)), alice);
            transfer::public_transfer(nft_farm::new_account(&farm, ctx(test)), bob);

            transfer::public_share_object(farm);
            transfer::public_transfer(cap, alice);
        };

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let nft = test_nft::new(ctx(test));

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut account,
                &policy,
                &mut kiosk,
                nft,
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };

        // Get all rewards
        clock::increment_for_testing(&mut c, (6 * 1000));

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);

            let pending_rewards = nft_farm::pending_rewards(&farm, &account, &c);

            let reward_coin = nft_farm::withdraw_rewards(
                &mut farm,
                &mut account,
                &c,
                ctx(test),
            );

            assert_eq(burn_for_testing(reward_coin), 5 * REWARDS_PER_SECOND);
            assert_eq(pending_rewards, 5 * REWARDS_PER_SECOND);
            assert_eq(nft_farm::amount(&account), 1);
            assert_eq(
                nft_farm::reward_debt(&account),
                (5 * REWARDS_PER_SECOND) as u256,
            );
            assert_eq(nft_farm::last_reward_timestamp(&farm), 6);
            assert_eq(
                nft_farm::accrued_rewards_per_share(&farm),
                (5 * REWARDS_PER_SECOND) as u256,
            );

            test::return_to_sender(test, account);
            test::return_shared(farm);
        };

        // Check if there are no rewards left
        clock::increment_for_testing(&mut c, 5 * 1000);

        next_tx(test, bob);
        {
            let farm = test::take_shared<Farm<NFT, SUI>>(test);

            assert_eq(nft_farm::balance_reward_coin(&farm), 0);

            test::return_shared(farm);
        };

        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    fun test_update_rewards_per_second() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let mut c = clock::create_for_testing(ctx(test));
        clock::increment_for_testing(&mut c, 10_000);

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let cap = test::take_from_sender<OwnerCap<FarmWitness>>(test);

            assert_eq(nft_farm::rewards_per_second(&farm), REWARDS_PER_SECOND);

            nft_farm::update_rewards_per_second(&mut farm, &cap, 1, &c);

            test::return_to_sender(test, cap);
            test::return_shared(farm);
        };
        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = owner::ENotAllowed)]
    fun test_wrong_admin_update_rewards() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let mut c = clock::create_for_testing(ctx(test));
        clock::increment_for_testing(&mut c, 10_000);

        next_tx(test, alice);
        {
            let wrong_cap = nft_farm::new_cap(ctx(test));
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);

            nft_farm::update_rewards_per_second(&mut farm, &wrong_cap, 1, &c);

            owner::destroy(wrong_cap);
            test::return_shared(farm);
        };
        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = owner::ENotAllowed)]
    fun test_wrong_admin_borrow_uid() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let mut c = clock::create_for_testing(ctx(test));
        clock::increment_for_testing(&mut c, 10_000);

        next_tx(test, alice);
        {
            let wrong_cap = nft_farm::new_cap(ctx(test));
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);

            nft_farm::borrow_mut_uid(&mut farm, &wrong_cap);

            owner::destroy(wrong_cap);
            test::return_shared(farm);
        };
        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = owner::ENotAllowed)]
    fun test_wrong_admin_destroy_farm() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            let wrong_cap = nft_farm::new_cap(ctx(test));

            let mut cap = nft_farm::new_cap(ctx(test));
            let farm = nft_farm::new_farm<NFT, SUI>(
                &mut cap,
                &c,
                REWARDS_PER_SECOND,
                START_TIME,
                ctx(test),
            );

            nft_farm::destroy_zero_farm(farm, &wrong_cap);

            transfer::public_transfer(cap, alice);
            owner::destroy(wrong_cap);
        };
        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[lint_allow(share_owned)]
    #[expected_failure(abort_code = nft_farm::EInvalidStartTime)]
    fun test_invalid_start_time() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        let c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            let mut cap = nft_farm::new_cap(ctx(test));
            let farm = nft_farm::new_farm<NFT, SUI>(
                &mut cap,
                &c,
                REWARDS_PER_SECOND,
                0,
                ctx(test),
            );

            // send accounts to people
            transfer::public_transfer(nft_farm::new_account(&farm, ctx(test)), alice);

            transfer::public_share_object(farm);
            transfer::public_transfer(cap, alice);
        };

        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = nft_farm::EAccountHasValue)]
    fun test_destroy_non_zero_account() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut account,
                &policy,
                &mut kiosk,
                test_nft::new(ctx(test)),
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            nft_farm::destroy_zero_account(account);

            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };
        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = nft_farm::EInvalidAccount)]
    fun test_stake_invalid_account() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut cap = nft_farm::new_cap(ctx(test));

            let farm2 = nft_farm::new_farm<NFT, SUI>(
                &mut cap,
                &c,
                REWARDS_PER_SECOND,
                START_TIME,
                ctx(test),
            );

            let mut wrong_account = nft_farm::new_account(&farm2, ctx(test));

            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut wrong_account,
                &policy,
                &mut kiosk,
                test_nft::new(ctx(test)),
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            transfer::public_transfer(wrong_account, alice);
            transfer::public_transfer(cap, alice);
            test::return_shared(farm);
            test::return_shared(farm2);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };
        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = nft_farm::EInvalidAccount)]
    fun test_unstake_invalid_account() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut cap = nft_farm::new_cap(ctx(test));

            let farm2 = nft_farm::new_farm<NFT, SUI>(
                &mut cap,
                &c,
                REWARDS_PER_SECOND,
                START_TIME,
                ctx(test),
            );

            let mut wrong_account = nft_farm::new_account(&farm2, ctx(test));

            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let nft_ = test_nft::new(ctx(test));

            let (reward_coin, nft, request) = nft_farm::unstake(
                &mut farm,
                &mut wrong_account,
                &mut kiosk,
                object::id(&nft_),
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            transfer::public_transfer(wrong_account, alice);
            transfer::public_transfer(cap, alice);
            transfer_policy::confirm_request(&policy, request);
            test::return_shared(farm);
            test::return_shared(farm2);
            test::return_shared(kiosk);
            test::return_shared(policy);
            test_nft::burn(nft);
            test_nft::burn(nft_);
        };
        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = nft_farm::EInvalidNFT)]
    fun test_unstake_invalid_nft() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        set_up(test);

        let c = clock::create_for_testing(ctx(test));

        next_tx(test, alice);
        {
            let mut farm = test::take_shared<Farm<NFT, SUI>>(test);
            let mut account = test::take_from_sender<Account<NFT, SUI>>(test);
            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);

            let nft = test_nft::new(ctx(test));

            let reward_coin = nft_farm::stake(
                &mut farm,
                &mut account,
                &policy,
                &mut kiosk,
                nft,
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            test::return_to_sender(test, account);
            test::return_shared(farm);
            test::return_shared(kiosk);
            test::return_shared(policy);
        };

        next_tx(test, alice);
        {
            let mut cap = nft_farm::new_cap(ctx(test));

            let mut farm2 = nft_farm::new_farm<NFT, SUI>(
                &mut cap,
                &c,
                REWARDS_PER_SECOND,
                START_TIME,
                ctx(test),
            );

            let mut wrong_account = nft_farm::new_account(&farm2, ctx(test));

            let mut kiosk = test::take_shared<Kiosk>(test);
            let policy = test::take_shared<TransferPolicy<NFT>>(test);
            let wrong_nft = test_nft::new(ctx(test));
            let (reward_coin, nft, request) = nft_farm::unstake(
                &mut farm2,
                &mut wrong_account,
                &mut kiosk,
                object::id(&wrong_nft),
                &c,
                ctx(test),
            );

            burn_for_testing(reward_coin);
            transfer::public_transfer(wrong_account, alice);
            transfer::public_transfer(cap, alice);
            transfer_policy::confirm_request(&policy, request);
            test::return_shared(farm2);
            test::return_shared(kiosk);
            test::return_shared(policy);
            test_nft::burn(nft);
            test_nft::burn(wrong_nft);
        };

        clock::destroy_for_testing(c);
        test::end(scenario);
    }

    #[lint_allow(share_owned)]
    fun set_up(test: &mut Scenario) {
        let (alice, bob) = people();

        next_tx(test, alice);
        {
            test_nft::test_init(ctx(test));
        };

        next_tx(test, alice);
        {
            let c = clock::create_for_testing(ctx(test));

            let mut cap = nft_farm::new_cap(ctx(test));
            let mut farm = nft_farm::new_farm<NFT, SUI>(
                &mut cap,
                &c,
                REWARDS_PER_SECOND,
                START_TIME,
                ctx(test),
            );

            nft_farm::add_rewards(
                &mut farm,
                &c,
                mint_for_testing(10_000_000_000 * 1_000, ctx(test)),
            );

            // send accounts to people
            transfer::public_transfer(nft_farm::new_account(&farm, ctx(test)), alice);
            transfer::public_transfer(nft_farm::new_account(&farm, ctx(test)), bob);

            transfer::public_share_object(farm);
            transfer::public_transfer(cap, alice);
            clock::destroy_for_testing(c);
        };
    }
}
