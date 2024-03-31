#[test_only]
module suitears::acess_control_tests {

  use sui::object::id_address;
  use sui::test_utils::{assert_eq, destroy};
  use sui::tx_context::{dummy, new_from_hint};

  use suitears::access_control;

  const TEST_ROLE: vector<u8> = b"TEST_ROLE";

  #[test]
  fun test_new() {
    let (ac, super_admin) = access_control::new(&mut dummy());

    assert_eq(access_control::access_control(&super_admin), id_address(&ac));
    assert_eq(access_control::has_role(&super_admin, &ac, access_control::super_admin_role()), true);

    destroy(ac);
    destroy(super_admin);
  }

  #[test]
  fun test_new_admin() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());

   assert_eq(access_control::access_control(&admin), id_address(&ac));

   destroy(ac);
   destroy(admin);
   destroy(super_admin);   
  }

  #[test]
  fun test_add() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   assert_eq(access_control::contains(&ac, TEST_ROLE), false);

   access_control::add(&super_admin, &mut ac, TEST_ROLE);
   // Can add the same role safely.
   access_control::add(&super_admin, &mut ac, TEST_ROLE);

   assert_eq(access_control::contains(&ac, TEST_ROLE), true);

   destroy(ac);
   destroy(super_admin);   
  }

  #[test]
  fun test_remove() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   access_control::add(&super_admin, &mut ac, TEST_ROLE);
   assert_eq(access_control::contains(&ac, TEST_ROLE), true);

   access_control::remove(&super_admin, &mut ac, TEST_ROLE);
   assert_eq(access_control::contains(&ac, TEST_ROLE), false);

   destroy(ac);
   destroy(super_admin);   
  } 

  #[test]
  fun test_grant() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());

   assert_eq(access_control::has_role(&admin, &ac, TEST_ROLE), false);
   
   access_control::grant(&super_admin, &mut ac, TEST_ROLE, id_address(&admin));

   assert_eq(access_control::has_role(&admin, &ac, TEST_ROLE), true);

   destroy(ac);
   destroy(admin);
   destroy(super_admin);   
  }  

  #[test]
  fun test_revoke() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());
   
   access_control::grant(&super_admin, &mut ac, TEST_ROLE, id_address(&admin));

   assert_eq(access_control::has_role(&admin, &ac, TEST_ROLE), true);

   access_control::revoke(&super_admin, &mut ac, TEST_ROLE, id_address(&admin));
   // Can revoke twice without throwing.
   access_control::revoke(&super_admin, &mut ac, TEST_ROLE, id_address(&admin));

   assert_eq(access_control::has_role(&admin, &ac, TEST_ROLE), false);

   destroy(ac);
   destroy(admin);
   destroy(super_admin);   
  }     

  #[test]
  fun test_renounce() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());
   
   access_control::grant(&super_admin, &mut ac, TEST_ROLE, id_address(&admin));

   assert_eq(access_control::has_role(&admin, &ac, TEST_ROLE), true);

   access_control::renounce(&admin, &mut ac, TEST_ROLE);
   // Can renounce twice without throwing.
   access_control::renounce(&admin, &mut ac, TEST_ROLE);

   assert_eq(access_control::has_role(&admin, &ac, TEST_ROLE), false);

   destroy(ac);
   destroy(admin);
   destroy(super_admin);   
  }  

  #[test]
  fun test_destroy() {
    let (ac, super_admin) = access_control::new(&mut dummy());

    access_control::destroy(&super_admin, ac);
    destroy(super_admin);
  }  

  #[test]
  fun test_destroy_empty() {
    let (ac, super_admin) = access_control::new(&mut dummy());

    access_control::remove(&super_admin, &mut ac, access_control::super_admin_role());

    access_control::destroy_empty(ac);
    destroy(super_admin);
  }  

  #[test]
  fun test_destroy_account() {
    let (ac, super_admin) = access_control::new(&mut dummy());

    destroy(ac);
    access_control::destroy_account(super_admin);
  }   

  #[test]
  #[expected_failure(abort_code = access_control::EMustBeASuperAdmin)] 
  fun test_add_error_case() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());

   access_control::add(&admin, &mut ac, TEST_ROLE);

   destroy(ac);
   destroy(admin);
   destroy(super_admin);       
  }

  #[test]
  #[expected_failure(abort_code = access_control::EMustBeASuperAdmin)] 
  fun test_remove_error_case() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());

   access_control::remove(&admin, &mut ac, TEST_ROLE);

   destroy(ac);
   destroy(admin);
   destroy(super_admin);       
  }  

  #[test]
  #[expected_failure(abort_code = access_control::EMustBeASuperAdmin)] 
  fun test_grant_error_case_no_super_admin() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());

   access_control::grant(&super_admin, &mut ac, TEST_ROLE, id_address(&admin));

   access_control::remove(&admin, &mut ac, TEST_ROLE);

   destroy(ac);
   destroy(admin);
   destroy(super_admin);       
  }    

  #[test]
  #[expected_failure(abort_code = access_control::ERoleDoesNotExist)] 
  fun test_revoke_error_case_role_does_not_exist() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());

   access_control::revoke(&super_admin, &mut ac, TEST_ROLE, id_address(&admin));

   destroy(ac);
   destroy(admin);
   destroy(super_admin);       
  }

  #[test]
  #[expected_failure(abort_code = access_control::EMustBeASuperAdmin)] 
  fun test_revoke_error_must_be_super_admin() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());

   access_control::grant(&admin, &mut ac, TEST_ROLE, id_address(&admin));

   access_control::revoke(&admin, &mut ac, TEST_ROLE, id_address(&admin));

   destroy(ac);
   destroy(admin);
   destroy(super_admin);       
  } 

  #[test]
  #[expected_failure(abort_code = access_control::EInvalidAccessControlAddress)] 
  fun test_renounce_wrong_access_control() {
   let (ac, super_admin) = access_control::new(&mut dummy());
   let (ac2, super_admin2) = access_control::new(&mut new_from_hint(@0x5, 1, 2, 3, 4));

   let admin = access_control::new_admin(&ac2, &mut new_from_hint(@0x6, 1, 2, 3, 4));

   access_control::renounce(&admin, &mut ac, TEST_ROLE);

   destroy(ac);
   destroy(ac2);
   destroy(admin);
   destroy(super_admin);
   destroy(super_admin2);       
  }  

  #[test]
  #[expected_failure(abort_code = access_control::EMustBeASuperAdmin)] 
  fun test_destroy_error_must_be_super_admin() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   let admin = access_control::new_admin(&ac, &mut dummy());

   access_control::destroy(&admin, ac);
   destroy(admin);
   destroy(super_admin);       
  }    

  #[test]
  #[expected_failure] 
  fun test_destroy_empty_error_must_be_super_admin() {
   let (ac, super_admin) = access_control::new(&mut dummy());

   access_control::destroy_empty( ac);
   destroy(super_admin);       
  }          
}