/*
* @title Access Control
*
* @dev It allows an admin to manage access control via roles.
*/
module suitears::access_control {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::vec_map::{Self, VecMap};
  use sui::vec_set::{Self, VecSet};

  // === Errors ===

  const EInvalidAccessControlAddress: u64 = 0;
  const EMustBeADefaultAdmin: u64 = 1;
  const ERoleDoesNotExist: u64 = 2;

  // === Constants ===

  const DEFAULT_ADMIN_ROLE: vector<u8> = b"DEFAULT_ADMIN_ROLE";

  // === Structs ===

  struct AccessControl has key, store {
   id: UID,
   roles: VecMap<vector<u8>, VecSet<address>>
  }

  struct Admin has key, store {
   id: UID,
   access_control: address
  }

  // === Public-Mutative Functions ===

  public fun new(ctx: &mut TxContext): (AccessControl, Admin) {
   let access_control = AccessControl {
    id: object::new(ctx),
    roles: vec_map::empty()
   };

   let default_admin = new_admin(&access_control, ctx);

   new_role_singleton_impl(&mut access_control, DEFAULT_ADMIN_ROLE, object::id_address(&default_admin));
   
   (access_control, default_admin)
  }

  public fun new_admin(self: &AccessControl, ctx: &mut TxContext): Admin {
   Admin {
    id: object::new(ctx),
    access_control: object::id_address(self)
   }
  }

  public fun new_role(admin: &Admin, self: &mut AccessControl, role: vector<u8>) {
    assert_default_admin(admin, self);

    if (!contains(self, role))
      new_role_impl(self, role);
  }

  public fun grant(admin: &Admin, self: &mut AccessControl, role: vector<u8>, new_admin: address) {
    assert_default_admin(admin, self);
    assert!(contains(self, role), ERoleDoesNotExist);

    if (contains(self, role))
      vec_set::insert(vec_map::get_mut(&mut self.roles, &role), new_admin)
    else
      new_role_singleton_impl(self, role, new_admin);
  }

  public fun revoke(
    admin: &Admin, 
    self: &mut AccessControl, 
    role: vector<u8>, 
    old_admin: address
  ) {
    assert_default_admin(admin, self);
    assert!(contains(self, role), ERoleDoesNotExist);

    if (has_role_(old_admin, self, role)) 
      vec_set::remove(vec_map::get_mut(&mut self.roles, &role), &old_admin);
  }

  public fun renounce(admin: &Admin, self: &mut AccessControl, role: vector<u8>) {
    assert!(object::id_address(self) == admin.access_control, EInvalidAccessControlAddress);

    let old_admin = object::id_address(admin);

    if (has_role_(old_admin, self, role)) 
      vec_set::remove(vec_map::get_mut(&mut self.roles, &role), &old_admin);
  }

  public fun destroy(admin: &Admin, self: AccessControl) {
    assert_default_admin(admin, &self);

    let AccessControl { id, roles: _ } = self;

    object::delete(id);
  }

  public fun destroy_empty(admin: &Admin, self: AccessControl) {
    assert_default_admin(admin, &self);

    let AccessControl { id, roles } = self;

    vec_map::destroy_empty(roles);
    object::delete(id);
  }

  public fun destroy_account(admin: Admin) {
    let Admin { id, access_control: _  } = admin;
    object::delete(id);
  }
 
  public fun destroy_role(admin: &Admin, self: &mut AccessControl, role: vector<u8>) {
    assert_default_admin(admin, self);

    if (contains(self, role)) {
      vec_map::remove(&mut self.roles, &role);
    };
  }

  // === Public-View Functions ===

  public fun default_admin_role(): vector<u8> {
   DEFAULT_ADMIN_ROLE
  }

  public fun contains(self: &AccessControl, role: vector<u8>): bool {
    vec_map::contains(&self.roles, &role)
  }

  public fun has_role_(admin_address: address, self: &AccessControl, role: vector<u8>): bool {
   if (!vec_map::contains(&self.roles, &role)) return false;

   let roles = vec_map::get(&self.roles, &role);

   vec_set::contains(roles,&admin_address)
  }

  public fun has_role(admin: &Admin, self: &AccessControl, role: vector<u8>): bool {
   let admin_address = object::id_address(self);
   assert!(admin_address == admin.access_control, EInvalidAccessControlAddress);
   
   has_role_(admin_address, self, role)
  }

  // === Private Functions ===

  fun assert_default_admin(admin: &Admin, self: &AccessControl) {
    assert!(object::id_address(self) == admin.access_control, EInvalidAccessControlAddress);
    assert!(has_role(admin, self, DEFAULT_ADMIN_ROLE), EMustBeADefaultAdmin);
  }

  fun new_role_impl(self: &mut AccessControl, role: vector<u8>) {
    vec_map::insert(&mut self.roles, role, vec_set::empty());
  }

  fun new_role_singleton_impl(self: &mut AccessControl, role: vector<u8>, recipient: address) {
    vec_map::insert(&mut self.roles, role, vec_set::singleton(recipient));
  }
}