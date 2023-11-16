# Design Rules

### Suitears💧follows [Sui's framework API](https://github.com/MystenLabs/sui/tree/main/crates/sui-framework/packages/sui-framework) to make it easier for developers.

#### When applicable CRUD functions must be called:

- add
- remove
- exists
- contains
- new
- empty
- to_object_name
- from_object_name
- borrow_property_name
- borrow_mut_property_name

#### Functions that create objects must be called new

```Move
struct Object has key, store {
	id: UID
}

public fun new(ctx:&mut TxContext): Object
```

#### Functions that create data structures must be called empty

```Move
struct DataStructure has copy, drop, store {
	bits: vector<u8>
}

public fun empty(): DataStructure
```

#### Do not emit events. Sui emits native events on object mutations.

#### If a key only object is returned by a new function. A separate share function must be included. The share function must be named share_object_name

```Move
struct Profile has key {
	id: UID
}

public fun new(ctx:&mut TxContext): Profile

public fun share_profile(profile: Profile)
```

#### Getter and view functions must be the name of the property and it has to return a copy of it.

```Move
struct Profile has key {
	id: UID,
	name: String,
	age: u8
}

public fun name(self: &Profile): String

public fun age(self: &Profile): u8
```

#### Functions that return a reference must be named borrow_property_name or borrow_mut_property_name

```Move
struct Profile has key {
	id: UID,
	name: String,
	age: u8
}

public fun borrow_name(self: &Profile): &String

public fun borrow_mut_age(self: &mut Profile): &mut u8
```

#### Module must operate over one Object or Data Structure.

```Move
module suitears::wallet {
	struct Wallet has key, store {
		id: UID,
		amount: u64
	}
}

module suitears::claw_back_wallet {
	struct Wallet has key {
		id: UID,
		amount: u64
	}
}
```
