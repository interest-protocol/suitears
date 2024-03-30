/*
* @title Access Control
*
* @dev It allows an admin to manage access control via roles.
*/
module suitears::access_control {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::vec_map::{Self, VecMap};
  use sui::vec_set::{Self, VecSet};
  use sui::tx_context::{Self, TxContext};

  // === Friends ===

  // === Errors ===

  const EInvalidRolesAddress: u64 = 0;
  const ERoleNotInitiated: u64 = 1;

  // === Constants ===

  const DEFAULT_ADMIN_ROLE: vector<u8> = b"DEFAULT_ADMIN_ROLE";

  // === Structs ===

  struct Roles has key, store {
   id: UID,
   roles: VecMap<vector<u8>, RoleData>
  }

  struct RoleData has store {
   has_role: VecSet<address>,
   admin_role: vector<u8>
  }

  struct Admin has key, store {
   id: UID,
   roles_address: address
  }

  // === Public-Mutative Functions ===

  public fun new(ctx: &mut TxContext): Roles {
   Roles {
    id: object::new(ctx),
    roles: vec_map::empty()
   }
  }

  public fun new_admin(self: &Roles, ctx: &mut TxContext): Admin {
   Admin {
    id: object::new(ctx),
    roles_address: object::id_address(self)
   }
  }
 
  // === Public-View Functions ===

  public fun default_admin_role(): vector<u8> {
   DEFAULT_ADMIN_ROLE
  }

  public fun has_role(self: &Roles, admin: &Admin, role: vector<u8>): bool {
   assert!(object::id_address(self) == admin.roles_address, EInvalidRolesAddress);
   assert!(vec_map::contains(&self.roles, &role), ERoleNotInitiated);

   let role_data = vec_map::get(&self.roles, &role);

   vec_set::contains(&role_data.has_role,&object::id_address(admin))
  }

  public fun get_role_admin(self: &Roles, role: vector<u8>): vector<u8> {
   assert!(vec_map::contains(&self.roles, &role), ERoleNotInitiated);

   let role_data = vec_map::get(&self.roles, &role);

   role_data.admin_role
  }

  // === Admin Functions ===

  // === Public-Friend Functions ===

  // === Private Functions ===

  // === Test Functions ===
}