<p>  <img  width="246.5px"height="76.5px"  src="./assets/logo.png" /></p>

Production ready modules for Sui Move developers

## Installation

Add the following snippet in your `Move.tml`

```toml
[dependencies.SuiTears]
git = "https://github.com/interest-protocol/suitears.git"
subdir = "contracts/"
rev = "testnet"
```

## Contracts

The Sui Move contracts are located in the `contracts` directory.

```ml
airdrop
├─ airdrop — "An airdrop that distributes the tokens after a specific date"
├─ linear_vesting_airdrop — "An airdrop that distributes the tokens linearly"
├─ quadratic_vesting_airdrop — "An airdrop that distributes the tokens quadratically"
capabilities
├─ admin — "Admin authorization capability"
├─ owner — "Owner capability to give access to multiple objects"
├─ timelock — "Timelock capability to add a delay between actions"
collections
├─ ac_collection — "Capability access wrapper for collections"
├─ bitmap — "Bitmap implementation for sequential keys"
├─ list — "A scalable vector implementation using dynamic fields"
├─ wit_collection - "Witness access wrapper for collections"
defi
├─ farm — "Farm module to reward coins over time"
├─ fund — "Struct to track shares associated with underlying deposits/withdrawals"
├─ linear_vesting_wallet — "Wallet that allows linear withdrawals over time"
├─ quadratic_vesting_wallet — "Wallet that allows quadratic withdrawals over time"
governance
├─ dao — "Decentralized autonomous organization"
├─ dao_action — "Hot potato library to execute DAO proposals"
├─ dao_treasury — "A treasury plugin for the DAO module"
int
├─ i128 — "An object to handle i128 unsigned integers operations"
├─ i256 — "An object to handle i256 unsigned integers operations"
├─ i64 — "An object to handle i64 unsigned integers operations"
math
├─ fixed_point64 — "Fixed point math module for x << 64 numbers"
├─ fixed_pointray — "Fixed point math module for numbers with 1e18 decimals"
├─ fixed_pointwad — "Fixed point math module for numbers with 1e9 decimals"
├─ math128 — "Utility math functions for u128 numbers"
├─ math256 — "Utility math functions for u256 numbers"
├─ math64 — "Utility math functions for u64 numbers"
├─ math_fixed64 — "Utility math functions for x << 64 numbers"
sft
├─ sft — "Semi Fungible Tokens"
├─ sft_balance — "Balance for Semi Fungible Tokens"
utils
├─ comparator — "Module to compare u8 vectors (bits)"
├─ ens_merkle_proof — "Module to verify Merkle proofs"
├─ merkle_proof — "Module to verify Merkle proofs"
├─ upgrade — "Module to add a timelock to contract upgrades"
├─ vectors — "Utility functions for vectors"
├─ whitelist — "A plugin to add whitelist functionalities to any object"
```

## Directories

```ml
contracts — "Move modules"
utils - "Typescript utilities to support Move modules"
audits - "Audit reports"
```

## Contributing

This repository is meant to provide Sui Move developers with production ready plug and play modules.

Feel free to make a pull request.

Do refer to the [contribution guidelines](https://github.com/interest-protocol/suitears/blob/main/CONTRIBUTING.md) for more details.

## Safety

This is provided on an "as is" and "as available" basis.

We **do not give any warranties** and **will not be liable for any loss** incurred through any use of this codebase.

While Suitears💧 has been heavily tested, there may be parts that may exhibit unexpected emergent behavior when used with other code, or may break in future Solidity versions.

Please always include your own thorough tests when using Suitears💧 to make sure it works correctly with your code.
