/*
 * @title Dao Treasury
 *
 * @notice Treasury for {Dao} to allow them to receive and send `sui::coin::Coin`.
 */
module suitears::dao_treasury {
    // === Imports ===

    use std::type_name::{Self, TypeName};

    use sui::event::emit;
    use sui::clock::Clock;
    use sui::bag::{Self, Bag};
    use sui::coin::{Self, Coin};
    use sui::balance;

    use suitears::dao_admin::DaoAdmin;
    use suitears::fixed_point_roll::mul_up;
    use suitears::linear_vesting_wallet::{Self, Wallet as LinearWallet};

    /* friend suitears::dao; */


    // === Constants ===

    // @dev The flash loan fee.
    const FLASH_LOAN_FEE: u64 = 5000000;
    // 0.5%

    // === Errors ===

    // @dev Thrown when the borrower does not repay the correct amount.
    const ERepayAmountTooLow: u64 = 0;

    // === Struct ===

    public struct DaoTreasury<phantom DaoWitness: drop> has key, store {
        id: UID,
        // Stores coins
        coins: Bag,
        // The `sui::object::ID` of the {Dao} that owns this {DaoTreasury}
        dao: ID
    }

    // * IMPORTANT do not add abilities
    public struct FlashLoan<phantom DaoWitness, phantom CoinType> {
        // The amount being borrowed
        amount: u64,
        // The fee amount to be repaid
        fee: u64,
        // The `std::type_name::TypeName` of the CoinType to repay the loan.
        `type`: TypeName
    }

    // === Events ===

    public struct Donate<phantom DaoWitness, phantom CoinType> has copy, drop {
        value: u64,
        donator: address
    }

    public struct Transfer<phantom DaoWitness, phantom CoinType> has copy, drop {
        value: u64,
        sender: address
    }

    public struct TransferLinearWallet<phantom DaoWitness, phantom CoinType> has copy, drop {
        value: u64,
        sender: address,
        wallet_id: ID,
        start: u64,
        duration: u64
    }

    public struct FlashLoanRequest<phantom DaoWitness, phantom CoinType> has copy, drop {
        borrower: address,
        treasury_id: ID,
        value: u64,
        `type`: TypeName
    }

    // === Public Friend Create Function ===

    /*
     * @notice Creates a {DaoTreasury} for the {Dao} with `sui::object::ID`  `dao`.
     *
     * @param dao The `sui::object::ID` of a {Dao}
     * @return DaoTreasury<DaoWitness>
     */
    public(package) fun new<DaoWitness: drop>(dao: ID, ctx: &mut TxContext): DaoTreasury<
        DaoWitness
    > {
        DaoTreasury {id: object::new(ctx), coins: bag::new(ctx), dao}
    }

    // === Public View Function ===

    /*
     * @notice Returns the `sui::object::ID` of the  {Dao} that owns the `treasury`.
     *
     * @param treasury A {DaoTreasury<DaoWitness>}
     * @return ID
     */
    public fun dao<DaoWitness: drop>(treasury: &DaoTreasury<DaoWitness>): ID {
        treasury.dao
    }

    /*
     * @notice Returns the amount of Coin<CoinType> in the `treasury`.
     *
     * @param treasury A {DaoTreasury<DaoWitness>}
     * @return u64
     */
    public fun balance<DaoWitness: drop, CoinType>(treasury: &DaoTreasury<DaoWitness>): u64 {
        let key = type_name::get<CoinType>();
        if (!treasury.coins.contains(key)) return 0;

        balance::value<CoinType>(&treasury.coins[key])
    }

    // === Public Mutative Functions ===

    /*
     * @notice Adds `token` to the `treasury`.
     *
     * @param treasury A {DaoTreasury<DaoWitness>}
     * @param token It will be donated to the `treasury`.
     */
    public fun donate<DaoWitness: drop, CoinType>(
        treasury: &mut DaoTreasury<DaoWitness>,
        token: Coin<CoinType>,
        ctx: &mut TxContext,
    ) {
        let key = type_name::get<CoinType>();
        let value = token.value();

        if (!treasury.coins.contains(key)) {
            treasury.coins.add(key, token.into_balance())
        } else {
            balance::join(&mut treasury.coins[key], token.into_balance());
        };

        emit(Donate<DaoWitness, CoinType> {value, donator: tx_context::sender(ctx)});
    }

    /*
     * @notice Withdraws a coin from the `treasury`.
     *
     * @param treasury A {DaoTreasury<DaoWitness>}.
     * @param _ Immutable reference to the {DaoAdmin}.
     * @param value The amount to withdraw.
     * @return Coin<CoinType>
     */
    public fun transfer<DaoWitness: drop, CoinType, TransferCoin>(
        treasury: &mut DaoTreasury<DaoWitness>,
        _: &DaoAdmin<DaoWitness>,
        value: u64,
        ctx: &mut TxContext,
    ): Coin<CoinType> {
        let token = coin::take(&mut treasury.coins[type_name::get<TransferCoin>()], value, ctx);

        emit(Transfer<DaoWitness, CoinType> {value: value, sender: tx_context::sender(ctx)});

        token
    }

    /*
     * @notice Withdraws a {LinearWallet<CoinTYpe>} from the `treasury`.
     *
     * @param treasury A {DaoTreasury<DaoWitness>}.
     * @param _ Immutable reference to the {DaoAdmin}.
     * @param c The `sui::clock::Clock`
     * @param value The amount to withdraw.
     * @param start Dictate when the vesting schedule starts.
     * @param duration The duration of the vesting schedule.
     * @return LinearWallet<CoinTYpe>.
     */
    public fun transfer_linear_vesting_wallet<DaoWitness: drop, CoinType, TransferCoin>(
        treasury: &mut DaoTreasury<DaoWitness>,
        _: &DaoAdmin<DaoWitness>,
        c: &Clock,
        value: u64,
        start: u64,
        duration: u64,
        ctx: &mut TxContext,
    ): LinearWallet<CoinType> {
        let token = coin::take<CoinType>(
            &mut treasury.coins[type_name::get<TransferCoin>()],
            value,
            ctx,
        );

        let wallet = linear_vesting_wallet::new(token, c, start, duration, ctx);

        emit(
            TransferLinearWallet<DaoWitness, CoinType> {
                value,
                sender: tx_context::sender(ctx),
                duration,
                start,
                wallet_id: object::id(&wallet),
            },
        );

        wallet
    }

    // === Flash Loan Functions ===

    /*
     * @notice Requests a Flash Loan from the `treasury`.
     *
     * @param treasury A {DaoTreasury<DaoWitness>}.
     * @param value The amount of the loan.
     * @return Coin<CoinType>. The coin that is being borrowed.
     * @return FlashLoan<DaoWitness, CoinType>
     */
    public fun flash_loan<DaoWitness: drop, CoinType>(
        treasury: &mut DaoTreasury<DaoWitness>,
        value: u64,
        ctx: &mut TxContext,
    ): (Coin<CoinType>, FlashLoan<DaoWitness, CoinType>) {
        let coin_type = type_name::get<CoinType>();
        let amount = balance::value<CoinType>(&treasury.coins[coin_type]);

        emit(
            FlashLoanRequest<DaoWitness, CoinType> {
                `type`: coin_type,
                borrower: ctx.sender(),
                value,
                treasury_id: object::id(treasury),
            },
        );

        (
            coin::take<CoinType>(&mut treasury.coins[coin_type], value, ctx),
            FlashLoan {amount, `type`: coin_type, fee: mul_up(value, FLASH_LOAN_FEE)}
        )
    }

    /*
     * @notice Returns the service fee amount that must be paid.
     *
     * @param flash_loan A {FlashLoan} hot potato.
     * @return u64
     */
    public fun fee<DaoWitness: drop, CoinType>(flash_loan: &FlashLoan<DaoWitness, CoinType>): u64 {
        flash_loan.fee
    }

    /*
     * @notice Returns the amount of the loan without the fees.
     *
     * @param flash_loan A {FlashLoan} hot potato.
     * @return u64
     */
    public fun amount<DaoWitness: drop, CoinType>(
        flash_loan: &FlashLoan<DaoWitness, CoinType>,
    ): u64 {
        flash_loan.amount
    }

    /*
     * @notice Repays the `flash_loan` to the `treasury`.
     *
     * @param treasury A {DaoTreasury<DaoWitness>}.
     * @param flash_loan A {FlashLoan} hot potato.
     * @param token The coin borrowed. Loan amount + fee amount.
     *
     * aborts-if:
     * - `token.value` is smaller than the initial loan amount + fee amount.
     */
    public fun repay_flash_loan<DaoWitness: drop, CoinType>(
        treasury: &mut DaoTreasury<DaoWitness>,
        flash_loan: FlashLoan<DaoWitness, CoinType>,
        token: Coin<CoinType>,
    ) {
        let FlashLoan { amount, `type`: coin_type, fee } = flash_loan;
        assert!(token.value() >= amount + fee, ERepayAmountTooLow);

        balance::join(&mut treasury.coins[coin_type], token.into_balance());
    }
}
