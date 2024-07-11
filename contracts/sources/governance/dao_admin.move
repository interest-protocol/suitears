/*
 * @title Dao Admin
 *
 * @notice It creates a capability to enable Daos to update their settings and interact with the treasury.
 */
module suitears::dao_admin {
    // === Imports ===

    // === Friends ===

    /* friend suitears::dao; */


    // === Struct ===

    public struct DaoAdmin<phantom OTW: drop> has key, store { id: UID }

    /*
     * @notice Creates a {DaoAdmin<OTW>}
     *
     * @return DaoAdmin
     */
    public(package) fun new<OTW: drop>(ctx: &mut TxContext): DaoAdmin<OTW> {
        DaoAdmin {id: object::new(ctx)}
    }
}
