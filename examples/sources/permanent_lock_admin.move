module examples::permanent_lock_admin {
    use sui::clock::Clock;
    use sui::tx_context::TxContext;
    use sui::types::is_one_time_witness;    

    use examples::permanent_lock::{Self, PermanentLock};

    const EInvalidWitness: u64 = 0;

     /*
     * Use PTBs
     * 1 -> Call unlock_temporarily::unlock_unlock_temporarily to get the AdminCap<T>
     * 2 -> Call Admin Function with &AdminCap<T>
     * 3 -> Call permanent_lock::relock_permanently to relock and store the AdminCap<T> again
     */
    struct AdminCap<phantom T> has store {}

    public fun create<T: drop>(otw: T, c: &Clock, time_delay: u64, ctx: &mut TxContext): PermanentLock<AdminCap<T>> {
      assert!(is_one_time_witness(&otw), EInvalidWitness);

      permanent_lock::lock(AdminCap {}, c, time_delay, ctx)
    }
}