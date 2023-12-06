// Source & inspired from Scallop 
// Whitelist implementation
module examples::whitelist {
  use sui::object::UID;
  use sui::dynamic_field as df;

  struct Mode has copy, drop, store {}

  struct Whitelisted has copy, drop, store { user: address }
  struct Blacklisted has copy, drop, store { user: address }

  const ACCEPT_ALL_MODE: u64 = 0;
  const REJECT_ALL_MODE: u64 = 1;
  const WHITELIST_MODE: u64 = 2;

  const EWrongMode: u64 = 0;
  const ENotWhitelisted: u64 = 1;
  const ENotBlacklisted: u64 = 2;
  const ENotAllowed: u64 = 3;

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
    remove_blacklist_address(self, user);
    if (df::exists_(self, Whitelisted { user })) return;
    df::add(self, Whitelisted { user }, user);
  }

  public fun remove_whitelist_address(self: &mut UID, user: address) {
    if (!df::exists_(self, Whitelisted { user })) return;
    df::remove<Whitelisted, address>(self, Whitelisted { user });
  }

  public fun blacklist_address(self: &mut UID, user: address) {
    remove_whitelist_address(self, user);
    if (df::exists_(self, Blacklisted { user })) return;
    df::add(self, Blacklisted { user }, user);
  }

  public fun remove_blacklist_address(self: &mut UID, user: address) {
    if (!df::exists_(self, Blacklisted { user })) return;
    df::remove<Blacklisted, address>(self, Blacklisted { user });
  }

  // @dev Blacklist has the highest precedence
  public fun is_whitelisted(self: &UID, user: address): bool {
    df::exists_(self, Whitelisted { user }) && !is_blacklisted(self, user)
  }

  public fun is_blacklisted(self: &UID, user: address): bool {
    df::exists_(self, Blacklisted { user })
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

  // @dev Precedence blacklist => reject all => whitelist => accept all
  // Whitelisted addresses only work on whitelist mode
  public fun is_user_allowed(self: &UID, user: address): bool {
    if (is_blacklisted(self, user) || is_rejecting_all(self)) return false;
    if (is_whitelist_mode(self) && is_whitelisted(self, user)) return true;
    !is_whitelist_mode(self)
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

  public fun assert_is_blacklisted(self: &UID, user: address) {
    assert!(is_blacklisted(self, user), ENotBlacklisted);
  }

  public fun assert_is_whitelisted(self: &UID, user: address) {
    assert!(is_whitelisted(self, user), ENotWhitelisted);
  }

  public fun assert_is_user_allowed(self: &UID, user: address) {
    assert!(is_user_allowed(self, user), ENotAllowed);
  }
}