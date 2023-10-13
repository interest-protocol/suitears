// Source & inspired from Scallop
module suitears::whitelist {

  use sui::object::UID;
  use sui::dynamic_field as df;

  struct Mode has copy, drop, store {}

  struct Whitelisted has copy, drop, store { user: address }

  const ACCEPT_ALL_MODE: u64 = 0;
  const REJECT_ALL_MODE: u64 = 1;
  const WHITELIST_MODE: u64 = 2;

  const EWrongMode: u64 = 0;
  const ENotWhitelisted: u64 = 1;

  public fun accept_all(self: &mut UID) {
    if (!df::exists_(self, Mode {})) {
      df::add(self, Mode {}, ACCEPT_ALL_MODE);
      return
    };

    let mode = df::borrow_mut(self, Mode {});
    *mode = ACCEPT_ALL_MODE;
  }

  public fun reject_all(self: &mut UID){
    if (!df::exists_(self, Mode {})) {
      df::add(self, Mode {}, REJECT_ALL_MODE);
      return
    };

    let mode = df::borrow_mut(self, Mode {});
    *mode = REJECT_ALL_MODE;
  }

  public fun set_to_whitelist(self: &mut UID){
    if (!df::exists_(self, Mode {})) {
      df::add(self, Mode {}, WHITELIST_MODE);
      return
    };

    let mode = df::borrow_mut(self, Mode {});
    *mode = WHITELIST_MODE;
  }

  public fun whitelist_address(self: &mut UID, user: address) {
    assert_is_whitelist_mode(self);
    df::add(self, Whitelisted { user }, user);
  }

  public fun is_whitelisted(self: &UID, user: address): bool {
    assert_is_whitelist_mode(self);
     (*df::borrow(self, Whitelisted { user }) == user)   
  }

  public fun is_accepting_all(self: &UID): bool {
    (*df::borrow(self, Mode {}) == ACCEPT_ALL_MODE)
  }

  public fun is_rejecting_all(self: &UID): bool {
    (*df::borrow(self, Mode {}) == REJECT_ALL_MODE)
  }

  public fun is_whitelist_mode(self: &UID): bool {
    (*df::borrow(self, Mode {}) == WHITELIST_MODE)
  }

  public fun assert_is_accepting_all(self: &UID) {
    assert!(is_accepting_all(self), EWrongMode);
  }

  public fun assert_is_rejecting_all(self: &UID) {
    assert!(is_rejecting_all(self), EWrongMode);
  }

  public fun assert_is_whitelist_mode(self: &UID) {
    assert!(is_whitelist_mode(self), EWrongMode);
  }

  public fun assert_is_whitelisted(self: &UID, user: address) {
    assert!(is_whitelisted(self, user), ENotWhitelisted);
  }
}