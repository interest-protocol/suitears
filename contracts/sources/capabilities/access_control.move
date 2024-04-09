/*
* @title Access Control
*
* @notice It allows an admin to manage access control via roles.
*/
module suitears::access_control {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::vec_map::{Self, VecMap};
  use sui::vec_set::{Self, VecSet};

  // === Errors ===

  /// The {Admin} was not created from {AccessControl}.  
  const EInvalidAccessControlAddress: u64 = 0;
  /// The {Admin} does not have the {SUPER_ADMIN_ROLE} role. 
  const EMustBeASuperAdmin: u64 = 1;
  /// The {AccessControl} does not have a role. 
  const ERoleDoesNotExist: u64 = 2;

  // === Constants ===

  /// {SUPER_ADMIN_ROLE}
  const SUPER_ADMIN_ROLE: vector<u8> = b"SUPER_ADMIN_ROLE";

  // === Structs ===

  struct AccessControl has key, store {
   id: UID,
   /// Map to store a role => set of addresses with said role.
   roles: VecMap<vector<u8>, VecSet<address>>
  }

  struct Admin has key, store {
   id: UID,
   /// Address of the {AccessControl} this capability belongs to.
   access_control: address
  }

  // === Public-Mutative Functions ===

  /*
  * @notice It creates an {AccessControl} and an {Admin} with the {SUPER_ADMIN_ROLE}.  
  *
  * @dev This is the admin of this module. This capability can create other admins.
  * The {AccessControl} can be shared or stored inside another shared object.
  *
  * @return {AccessControl}. It stores the role's data.  
  * @return {Admin}. The {SUPER_ADMIN_ROLE} {Admin}. 
  */
  public fun new(ctx: &mut TxContext): (AccessControl, Admin) {
   let access_control = AccessControl {
    id: object::new(ctx),
    roles: vec_map::empty()
   };

   let super_admin = new_admin(&access_control, ctx);

   new_role_singleton_impl(&mut access_control, SUPER_ADMIN_ROLE, object::id_address(&super_admin));
   
   (access_control, super_admin)
  }

  /*
  * @notice It creates a new {Admin} associated with the {AccessControl} without roles.  
  *
  * @param self The {AccessControl} object.  
  * @return {Admin}. An {Admin} without roles.
  */
  public fun new_admin(self: &AccessControl, ctx: &mut TxContext): Admin {
   Admin {
    id: object::new(ctx),
    access_control: object::id_address(self)
   }
  }

  /*
  * @notice It adds the `role` to the {AccessControl} object.     
  *
  * @dev It will not throw if the `role` has already been added. 
  *
  * @param admin A {SUPER_ADMIN_ROLE} {Admin}.
  * @param self The {AccessControl} object.  
  * @param role The role to be added to the `self`.
  *
  * aborts-if 
  * - `admin` is not a {SUPER_ADMIN_ROLE} {Admin}.
  * - `admin` was not created from the `self`.
  */
  public fun add(admin: &Admin, self: &mut AccessControl, role: vector<u8>) {
    assert_super_admin(admin, self);

    if (!contains(self, role))
      new_role_impl(self, role);
  }

  /*
  * @notice It removes the `role` from the {AccessControl} object.     
  *
  * @dev It will not throw if the `role` does not exist. 
  *
  * @param admin A {SUPER_ADMIN_ROLE} {Admin}.
  * @param self The {AccessControl} object.  
  * @param role The role to be removed from the `self`.
  *
  * aborts-if 
  * - `admin` is not a {SUPER_ADMIN_ROLE} {Admin}.
  * - `admin` was not created from the `self`.
  */
  public fun remove(admin: &Admin, self: &mut AccessControl, role: vector<u8>) {
    assert_super_admin(admin, self);

    if (contains(self, role)) {
      vec_map::remove(&mut self.roles, &role);
    };
  }

  /*
  * @notice It grants the `role` to an admin.     
  *
  * @dev The `new_admin` is the `sui::object::id_address` of an {Admin}.
  * It will not throw if the `new_admin` already has the `role`.
  *
  * @param admin A {SUPER_ADMIN_ROLE} {Admin}.
  * @param self The {AccessControl} object.  
  * @param role The role to be granted to the `new_admin`.
  * @param new_admin The address of an {Admin}.
  *
  * aborts-if 
  * - `admin` is not a {SUPER_ADMIN_ROLE} {Admin}.
  * - `admin` was not created from the `self`.
  * - `role` does not exist.
  */
  public fun grant(admin: &Admin, self: &mut AccessControl, role: vector<u8>, new_admin: address) {
    assert_super_admin(admin, self);

    if (contains(self, role))
      vec_set::insert(vec_map::get_mut(&mut self.roles, &role), new_admin)
    else
      new_role_singleton_impl(self, role, new_admin);
  }

  /*
  * @notice It revokes the `role` from an admin.     
  *
  * @dev The `old_admin` is the `sui::object::id_address` of an {Admin}.
  * It will not throw if the `old_admin` does not have the `role`.
  *
  * @param admin A {SUPER_ADMIN_ROLE} {Admin}.
  * @param self The {AccessControl} object.  
  * @param role The role to be removed from the `old_admin`.
  * @param old_admin The address of an {Admin}.
  *
  * aborts-if 
  * - `admin` is not a {SUPER_ADMIN_ROLE} {Admin}.
  * - `admin` was not created from the `self`.
  * - `role` does not exist.
  */
  public fun revoke(
    admin: &Admin, 
    self: &mut AccessControl, 
    role: vector<u8>, 
    old_admin: address
  ) {
    assert_super_admin(admin, self);
    assert!(contains(self, role), ERoleDoesNotExist);

    if (has_role_(old_admin, self, role)) 
      vec_set::remove(vec_map::get_mut(&mut self.roles, &role), &old_admin);
  }

  /*
  * @notice Allows an {Admin} to renounce a `role`.     
  *
  * @dev It will not throw if the `admin` does not have the `role`.
  *
  * @param admin An {Admin}.
  * @param self The {AccessControl} object.  
  * @param role The role that will be renounced.
  *
  * aborts-if 
  * - `admin` was not created from the `self`.
  */
  public fun renounce(admin: &Admin, self: &mut AccessControl, role: vector<u8>) {
    assert!(object::id_address(self) == admin.access_control, EInvalidAccessControlAddress);

    let old_admin = object::id_address(admin);

    if (has_role_(old_admin, self, role)) 
      vec_set::remove(vec_map::get_mut(&mut self.roles, &role), &old_admin);
  }

  /*
  * @notice Destroys an {AccessControl} object.     
  *
  * @dev Careful, this is irreversible and will break this module logic.
  * It does not check if the {AccessControl} has any roles registered.
  *
  * @param admin A {SUPER_ADMIN_ROLE} {Admin}.
  * @param self The {AccessControl} object.  
  *
  * aborts-if 
  * - `admin` is not a {SUPER_ADMIN_ROLE} {Admin}.
  * - `admin` was not created from the `self`.
  */
  public fun destroy(admin: &Admin, self: AccessControl) {
    assert_super_admin(admin, &self);

    let AccessControl { id, roles: _ } = self;

    object::delete(id);
  }

  /*
  * @notice Destroys an empty {AccessControl} object.     
  *
  * @dev Careful, this is irreversible.
  *
  * @param self The {AccessControl} object.  
  *
  * aborts-if 
  * - `self` is not empty.
  */
  public fun destroy_empty(self: AccessControl) {

    let AccessControl { id, roles } = self;

    vec_map::destroy_empty(roles);
    object::delete(id);
  }

  /*
  * @notice Destroys an {Admin}.     
  *
  * @param admin An {Admin}.
  */
  public fun destroy_account(admin: Admin) {
    let Admin { id, access_control: _  } = admin;
    object::delete(id);
  }

  // === Public-View Functions ===

  /*
  * @notice Returns the {SUPER_ADMIN_ROLE}.     
  *
  * @return {SUPER_ADMIN_ROLE}.
  */
  public fun super_admin_role(): vector<u8> {
   SUPER_ADMIN_ROLE
  }

  /*
  * @notice Returns the address of the {AccessControl} that created the `admin`.     
  *
  * @param admin An {Admin}.
  * @return address.
  */
  public fun access_control(admin: &Admin): address {
    admin.access_control
  }

  /*
  * @notice Checks if an {AccessControl} object has a `role`.     
  *
  * @param self The {AccessControl} object.  
  * @param role A role.
  * @return bool. True if it contains the `role`. 
  */
  public fun contains(self: &AccessControl, role: vector<u8>): bool {
    vec_map::contains(&self.roles, &role)
  }

  /*
  * @notice Checks if an {Admin} address has a `role`.     
  *
  * @dev It does not throw if the `role` does not exist.
  *
  * @param admin_address The `sui::object::id_address` of an {Admin}.
  * @param self The {AccessControl} object.  
  * @param role A role.
  * @return bool. True if it has the `role`. 
  */
  public fun has_role_(admin_address: address, self: &AccessControl, role: vector<u8>): bool {
   if (!vec_map::contains(&self.roles, &role)) return false;

   let roles = vec_map::get(&self.roles, &role);

   vec_set::contains(roles,&admin_address)
  }

  /*
  * @notice Checks if an {Admin} has a `role`.     
  *
  * @dev It does not throw if the `role` does not exist.
  *
  * @param admin An {Admin}.
  * @param self The {AccessControl} object.  
  * @param role A role.
  * @return bool. True if it has the `role`. 
  *
  * aborts-if 
  * - `admin` was not created from the `self`.
  */
  public fun has_role(admin: &Admin, self: &AccessControl, role: vector<u8>): bool {
   let ac_address = object::id_address(self);
   assert!(ac_address == admin.access_control, EInvalidAccessControlAddress);
   
   has_role_(object::id_address(admin), self, role)
  }

  // === Private Functions ===

  /*
  * @notice Asserts that the {Admin} has the {SUPER_ADMIN_ROLE} and was created from the `self`.     
  *
  * @param admin An {Admin}.
  * @param self The {AccessControl} object.  
  *
  * aborts-if 
  * - `admin` is not a {SUPER_ADMIN_ROLE} {Admin}.
  * - `admin` was not created from the `self`.
  */
  fun assert_super_admin(admin: &Admin, self: &AccessControl) {
    assert!(has_role(admin, self, SUPER_ADMIN_ROLE), EMustBeASuperAdmin);
  }

  /*
  * @notice Adds the `role` to the `self`.     
  *
  * @param self The {AccessControl} object.  
  * @param role The role to be added.
  *
  * aborts-if 
  * - `role` is already in the `self`.
  */
  fun new_role_impl(self: &mut AccessControl, role: vector<u8>) {
    vec_map::insert(&mut self.roles, role, vec_set::empty());
  }

  /*
  * @notice Adds the `role` and an admin with the new `role` to the `self`.     
  *
  * @param self The {AccessControl} object.  
  * @param role The role to be added.
  * @param recipient The new admin with the new `role`. 
  *
  * aborts-if 
  * - `role` is already in the `self`.
  */
  fun new_role_singleton_impl(self: &mut AccessControl, role: vector<u8>, recipient: address) {
    vec_map::insert(&mut self.roles, role, vec_set::singleton(recipient));
  }
}