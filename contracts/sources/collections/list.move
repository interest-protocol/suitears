// Src & Credit: https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/data_structures/smart_vector.move
module suitears::list {
    use std::vector;
    use std::option::{Self, Option};
    
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    use suitears::big_vector::{Self, BigVector};

    #[test_only]
    use sui::test_scenario::{Self as test, ctx};

    /// Vector index is out of bounds
    const EIndexOutOfBounds: u64 = 1;
    const EVectorEmpty: u64 = 2;
    const EVectorNotEmpty: u64 = 3;
    /// bucket_size cannot be 0
    const EZeroBucketSize: u64 = 4;

    /// A Scalable vector implementation based on tables, Ts are grouped into buckets with `bucket_size`.
    /// The option wrapping BigVector saves space in the metadata associated with BigVector when list is
    /// so small that inline_vec vector can hold all the data.
    struct List<T: store> has store {
        id: UID,
        inline_vec: vector<T>,
        big_vec: Option<BigVector<T>>,
        inline_capacity: Option<u64>,
        bucket_size: Option<u64>,
    }

    /// Regular Vector API

    /// Create an empty vector with customized config.
    /// When inline_capacity = 0, List degrades to a wrapper of BigVector.
    public fun new<T: store>(inline_capacity: u64, bucket_size: u64, ctx: &mut TxContext): List<T> {
        assert!(bucket_size > 0, EZeroBucketSize);
        List {
            id: object::new(ctx),
            inline_vec: vector[],
            big_vec: option::none(),
            inline_capacity: option::some(inline_capacity),
            bucket_size: option::some(bucket_size),
        }
    }

    /// Create a vector of length 1 containing the passed in T.
    public fun singleton<T: store>(inline_capacity: u64, bucket_size: u64, element: T, ctx: &mut TxContext): List<T> {
        let v = new(inline_capacity, bucket_size, ctx);
        push_back(&mut v, element, ctx);
        v
    }

    /// Destroy the vector `v`.
    /// Aborts if `v` is not empty.
    public fun destroy_empty<T: store>(v: List<T>) {
        assert!(is_empty(&v), EVectorNotEmpty);
        let List { id, inline_vec, big_vec, inline_capacity: _, bucket_size: _ } = v;
        vector::destroy_empty(inline_vec);
        option::destroy_none(big_vec);
        object::delete(id);
    }

    /// Destroy a vector completely when T has `drop`.
    public fun destroy<T: drop + store>(v: List<T>) {
        clear(&mut v);
        destroy_empty(v);
    }

    /// Clear a vector completely when T has `drop`.
    public fun clear<T: drop + store>(v: &mut List<T>) {
        v.inline_vec = vector[];
        if (option::is_some(&v.big_vec)) {
            big_vector::destroy(option::extract(&mut v.big_vec));
        }
    }

    /// Acquire an immutable reference to the `i`th T of the vector `v`.
    /// Aborts if `i` is out of bounds.
    public fun borrow<T: store>(v: &List<T>, i: u64): &T {
        assert!(i < length(v), EIndexOutOfBounds);
        let inline_len = vector::length(&v.inline_vec);
        if (i < inline_len) {
            vector::borrow(&v.inline_vec, i)
        } else {
            big_vector::borrow(option::borrow(&v.big_vec), i - inline_len)
        }
    }

    /// Return a mutable reference to the `i`th T in the vector `v`.
    /// Aborts if `i` is out of bounds.
    public fun borrow_mut<T: store>(v: &mut List<T>, i: u64): &mut T {
        assert!(i < length(v), EIndexOutOfBounds);
        let inline_len = vector::length(&v.inline_vec);
        if (i < inline_len) {
            vector::borrow_mut(&mut v.inline_vec, i)
        } else {
            big_vector::borrow_mut(option::borrow_mut(&mut v.big_vec), i - inline_len)
        }
    }

    /// Empty and destroy the other vector, and push each of the Ts in the other vector onto the lhs vector in the
    /// same order as they occurred in other.
    /// Disclaimer: This function may be costly. Use it at your own discretion.
    public fun append<T: store>(lhs: &mut List<T>, other: List<T>, ctx: &mut TxContext) {
        let other_len = length(&other);
        let half_other_len = other_len / 2;
        let i = 0;
        while (i < half_other_len) {
            push_back(lhs, swap_remove(&mut other, i), ctx);
            i = i + 1;
        };
        while (i < other_len) {
            push_back(lhs, pop_back(&mut other), ctx);
            i = i + 1;
        };
        destroy_empty(other);
    }

    /// Add multiple values to the vector at once.
    public fun add_all<T: store>(v: &mut List<T>, vals: vector<T>, ctx: &mut TxContext) {
      let len = vector::length(&vals);
      let i = 0;
      while (i < len) {
        push_back(v, vector::remove(&mut vals, 0), ctx);
        i = i + 1;
      };
      vector::destroy_empty(vals);
    }

    /// Convert a smart vector to a native vector, which is supposed to be called mostly by view functions to get an
    /// atomic view of the whole vector.
    /// Disclaimer: This function may be costly as the smart vector may be huge in size. Use it at your own discretion.
    public fun to_vector<T: store + copy>(v: &List<T>): vector<T> {
        let res = v.inline_vec;
        if (option::is_some(&v.big_vec)) {
            let big_vec = option::borrow(&v.big_vec);
            vector::append(&mut res, big_vector::to_vector(big_vec));
        };
        res
    }

    /// Add T `val` to the end of the vector `v`. It grows the buckets when the current buckets are full.
    /// This operation will cost more gas when it adds new bucket.
    public fun push_back<T: store>(v: &mut List<T>, val: T, ctx: &mut TxContext) {
        let len = length(v);
        let inline_len = vector::length(&v.inline_vec);
        if (len == inline_len) {
          if (len < *option::borrow(&v.inline_capacity)) {
            vector::push_back(&mut v.inline_vec, val);
            return
          };
          let bucket_size = *option::borrow(&v.bucket_size);
          option::fill(&mut v.big_vec, big_vector::new(bucket_size, ctx));
        };
        big_vector::push_back(option::borrow_mut(&mut v.big_vec), val);
    }

    /// Pop an T from the end of vector `v`. It does shrink the buckets if they're empty.
    /// Aborts if `v` is empty.
    public fun pop_back<T: store>(v: &mut List<T>): T {
        assert!(!is_empty(v), EVectorEmpty);
        let big_vec_wrapper = &mut v.big_vec;
        if (option::is_some(big_vec_wrapper)) {
            let big_vec = option::extract(big_vec_wrapper);
            let val = big_vector::pop_back(&mut big_vec);
            if (big_vector::is_empty(&big_vec)) {
                big_vector::destroy_empty(big_vec)
            } else {
                option::fill(big_vec_wrapper, big_vec);
            };
            val
        } else {
            vector::pop_back(&mut v.inline_vec)
        }
    }

    /// Remove the T at index i in the vector v and return the owned value that was previously stored at i in v.
    /// All Ts occurring at indices greater than i will be shifted down by 1. Will abort if i is out of bounds.
    /// Disclaimer: This function may be costly. Use it at your own discretion.
    public fun remove<T: store>(v: &mut List<T>, i: u64): T {
        let len = length(v);
        assert!(i < len, EIndexOutOfBounds);
        let inline_len = vector::length(&v.inline_vec);
        if (i < inline_len) {
            vector::remove(&mut v.inline_vec, i)
        } else {
            let big_vec_wrapper = &mut v.big_vec;
            let big_vec = option::extract(big_vec_wrapper);
            let val = big_vector::remove(&mut big_vec, i - inline_len);
            if (big_vector::is_empty(&big_vec)) {
                big_vector::destroy_empty(big_vec)
            } else {
                option::fill(big_vec_wrapper, big_vec);
            };
            val
        }
    }

    /// Swap the `i`th T of the vector `v` with the last T and then pop the vector.
    /// This is O(1), but does not preserve ordering of Ts in the vector.
    /// Aborts if `i` is out of bounds.
    public fun swap_remove<T: store>(v: &mut List<T>, i: u64): T {
        let len = length(v);
        assert!(i < len, EIndexOutOfBounds);
        let inline_len = vector::length(&v.inline_vec);
        let big_vec_wrapper = &mut v.big_vec;
        let inline_vec = &mut v.inline_vec;
        if (i >= inline_len) {
            let big_vec = option::extract(big_vec_wrapper);
            let val = big_vector::swap_remove(&mut big_vec, i - inline_len);
            if (big_vector::is_empty(&big_vec)) {
                big_vector::destroy_empty(big_vec)
            } else {
                option::fill(big_vec_wrapper, big_vec);
            };
            val
        } else {
            if (inline_len < len) {
                let big_vec = option::extract(big_vec_wrapper);
                let last_from_big_vec = big_vector::pop_back(&mut big_vec);
                if (big_vector::is_empty(&big_vec)) {
                    big_vector::destroy_empty(big_vec)
                } else {
                    option::fill(big_vec_wrapper, big_vec);
                };
                vector::push_back(inline_vec, last_from_big_vec);
            };
            vector::swap_remove(inline_vec, i)
        }
    }

    /// Swap the Ts at the i'th and j'th indices in the vector v. Will abort if either of i or j are out of bounds
    /// for v.
    public fun swap<T: store>(v: &mut List<T>, i: u64, j: u64) {
        if (i > j) {
            return swap(v, j, i)
        };
        let len = length(v);
        assert!(j < len, EIndexOutOfBounds);
        let inline_len = vector::length(&v.inline_vec);
        if (i >= inline_len) {
            big_vector::swap(option::borrow_mut(&mut v.big_vec), i - inline_len, j - inline_len);
        } else if (j < inline_len) {
            vector::swap(&mut v.inline_vec, i, j);
        } else {
            let big_vec = option::borrow_mut(&mut v.big_vec);
            let inline_vec = &mut v.inline_vec;
            let element_i = vector::swap_remove(inline_vec, i);
            let element_j = big_vector::swap_remove(big_vec, j - inline_len);
            vector::push_back(inline_vec, element_j);
            vector::swap(inline_vec, i, inline_len - 1);
            big_vector::push_back(big_vec, element_i);
            big_vector::swap(big_vec, j - inline_len, len - inline_len - 1);
        }
    }

    /// Reverse the order of the Ts in the vector v in-place.
    /// Disclaimer: This function may be costly. Use it at your own discretion.
    public fun reverse<T: store>(v: &mut List<T>, ctx: &mut TxContext) {
        let inline_len = vector::length(&v.inline_vec);
        let i = 0;
        let new_inline_vec = vector[];
        // Push the last `inline_len` Ts into a temp vector.
        while (i < inline_len) {
            vector::push_back(&mut new_inline_vec, pop_back(v));
            i = i + 1;
        };
        vector::reverse(&mut new_inline_vec);
        // Reverse the big_vector left if exists.
        if (option::is_some(&v.big_vec)) {
            big_vector::reverse(option::borrow_mut(&mut v.big_vec));
        };
        // Mem::swap the two vectors.
        let temp_vec = vector[];
        while (!vector::is_empty(&mut v.inline_vec)) {
            vector::push_back(&mut temp_vec, vector::pop_back(&mut v.inline_vec));
        };
        vector::reverse(&mut temp_vec);
        while (!vector::is_empty(&mut new_inline_vec)) {
            vector::push_back(&mut v.inline_vec, vector::pop_back(&mut new_inline_vec));
        };
        vector::destroy_empty(new_inline_vec);
        // Push the rest Ts originally left in inline_vector back to the end of the smart vector.
        while (!vector::is_empty(&mut temp_vec)) {
            push_back(v, vector::pop_back(&mut temp_vec), ctx);
        };
        vector::destroy_empty(temp_vec);
    }

    /// Return `(true, i)` if `val` is in the vector `v` at index `i`.
    /// Otherwise, returns `(false, 0)`.
    /// Disclaimer: This function may be costly. Use it at your own discretion.
    public fun index_of<T: store>(v: &List<T>, val: &T): (bool, u64) {
        let (found, i) = vector::index_of(&v.inline_vec, val);
        if (found) {
            (true, i)
        } else if (option::is_some(&v.big_vec)) {
            let (found, i) = big_vector::index_of(option::borrow(&v.big_vec), val);
            (found, i + vector::length(&v.inline_vec))
        } else {
            (false, 0)
        }
    }

    /// Return true if `val` is in the vector `v`.
    /// Disclaimer: This function may be costly. Use it at your own discretion.
    public fun contains<T: store>(v: &List<T>, val: &T): bool {
        if (is_empty(v)) return false;
        let (exist, _) = index_of(v, val);
        exist
    }

    /// Return the length of the vector.
    public fun length<T: store>(v: &List<T>): u64 {
        vector::length(&v.inline_vec) + if (option::is_none(&v.big_vec)) {
            0
        } else {
            big_vector::length(option::borrow(&v.big_vec))
        }
    }

    /// Return `true` if the vector `v` has no Ts and `false` otherwise.
    public fun is_empty<T: store>(v: &List<T>): bool {
        length(v) == 0
    }

    #[test]
    fun list_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;
        
        let v = new(7, 11, ctx(test));
        let i = 0;
        while (i < 100) {
            push_back(&mut v, i, ctx(test));
            i = i + 1;
        };
        let j = 0;
        while (j < 100) {
            let val = borrow(&v, j);
            assert!(*val == j, 0);
            j = j + 1;
        };
        while (i > 0) {
            i = i - 1;
            let (exist, index) = index_of(&v, &i);
            let j = pop_back(&mut v);
            assert!(exist, 0);
            assert!(index == i, 0);
            assert!(j == i, 0);
        };
        while (i < 100) {
            push_back(&mut v, i, ctx(test));
            i = i + 1;
        };
        let last_index = length(&v) - 1;
        assert!(swap_remove(&mut v, last_index) == 99, 0);
        assert!(swap_remove(&mut v, 0) == 0, 0);
        while (length(&v) > 0) {
            // the vector is always [N, 1, 2, ... N-1] with repetitive swap_remove(&mut v, 0)
            let expected = length(&v);
            let val = swap_remove(&mut v, 0);
            assert!(val == expected, 0);
        };
        destroy_empty(v);
        test::end(scenario);
    }

    #[test]
    fun list_append_edge_case_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;
        
        let v1 = new(7, 11, ctx(test));
        let v2 = singleton(7, 11, 1, ctx(test));
        let v3 = new(7, 11, ctx(test));
        let v4 = new(7, 11, ctx(test));
        append(&mut v3, v4, ctx(test));
        assert!(length(&v3) == 0, 0);
        append(&mut v2, v3, ctx(test));
        assert!(length(&v2) == 1, 0);
        append(&mut v1, v2, ctx(test));
        assert!(length(&v1) == 1, 0);
        destroy(v1);
        test::end(scenario);
    }

    #[test]
    fun list_append_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;

        let v1 = new(7, 11, ctx(test));
        let v2 = new(7, 11, ctx(test));
        let i = 0;
        while (i < 7) {
            push_back(&mut v1, i, ctx(test));
            i = i + 1;
        };
        while (i < 25) {
            push_back(&mut v2, i, ctx(test));
            i = i + 1;
        };
        append(&mut v1, v2, ctx(test));
        assert!(length(&v1) == 25, 0);
        i = 0;
        while (i < 25) {
            assert!(*borrow(&v1, i) == i, 0);
            i = i + 1;
        };
        destroy(v1);
        test::end(scenario);
    }

    #[test]
    fun list_remove_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;

        let v = new(12,9, ctx(test));
        let i = 0u64;
        while (i < 101) {
            push_back(&mut v, i, ctx(test));
            i = i + 1;
        };
        let inline_len = vector::length(&v.inline_vec);
        remove(&mut v, 100);
        remove(&mut v, 90);
        remove(&mut v, 80);
        remove(&mut v, 70);
        remove(&mut v, 60);
        remove(&mut v, 50);
        remove(&mut v, 40);
        remove(&mut v, 30);
        remove(&mut v, 20);
        assert!(vector::length(&v.inline_vec) == inline_len, 0);
        remove(&mut v, 10);
        assert!(vector::length(&v.inline_vec) + 1 == inline_len, 0);
        remove(&mut v, 0);
        assert!(vector::length(&v.inline_vec) + 2 == inline_len, 0);
        assert!(length(&v) == 90, 0);

        let index = 0;
        i = 0;
        while (i < 101) {
            if (i % 10 != 0) {
                assert!(*borrow(&v, index) == i, 0);
                index = index + 1;
            };
            i = i + 1;
        };
        destroy(v);
        test::end(scenario);
    }

    #[test]
    fun list_reverse_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;

        let v = new(12, 9, ctx(test));
        let i = 0u64;
        while (i < 10) {
            push_back(&mut v, i, ctx(test));
            i = i + 1;
        };
        reverse(&mut v, ctx(test));
        let k = 0;
        while (k < 10) {
            assert!(*vector::borrow(&v.inline_vec, k) == 9 - k, 0);
            k = k + 1;
        };
        while (i < 100) {
            push_back(&mut v, i, ctx(test));
            i = i + 1;
        };
        while (!vector::is_empty(&v.inline_vec)) {
            remove(&mut v, 0);
        };
        reverse(&mut v, ctx(test));
        i = 0;
        let len = length(&v);
        while (i + 1 < len) {
            assert!(
                *big_vector::borrow(option::borrow(&v.big_vec), i) == *big_vector::borrow(
                    option::borrow(&v.big_vec),
                    i + 1
                ) + 1,
                0
            );
            i = i + 1;
        };
        destroy(v);
        test::end(scenario);
    }

    #[test]
    fun list_add_all_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;

        let v = new(1, 2, ctx(test));
        add_all(&mut v, vector[1, 2, 3, 4, 5, 6], ctx(test));
        assert!(length(&v) == 6, 0);
        let i = 0;
        while (i < 6) {
            assert!(*borrow(&v, i) == i + 1, 0);
            i = i + 1;
        };
        destroy(v);
        test::end(scenario);
    }

    #[test]
    fun list_to_vector_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;

        let v1 = new(7, 1, ctx(test));
        let i = 0;
        while (i < 100) {
            push_back(&mut v1, i, ctx(test));
            i = i + 1;
        };
        let v2 = to_vector(&v1);
        let j = 0;
        while (j < 100) {
            assert!(*vector::borrow(&v2, j) == j, 0);
            j = j + 1;
        };
        destroy(v1);
        test::end(scenario);
    }

    #[test]
    fun list_swap_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;

        let v = new(7, 11, ctx(test));
        let i = 0;
        while (i < 101) {
            push_back(&mut v, i, ctx(test));
            i = i + 1;
        };
        i = 0;
        while (i < 51) {
            swap(&mut v, i, 100 - i);
            i = i + 1;
        };
        i = 0;
        while (i < 101) {
            assert!(*borrow(&v, i) == 100 - i, 0);
            i = i + 1;
        };
        destroy(v);
        test::end(scenario);
    }

    #[test]
    fun list_index_of_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;

        let v = new(7, 11, ctx(test));
        let i = 0;
        while (i < 100) {
            push_back(&mut v, i, ctx(test));
            let (found, idx) = index_of(&mut v, &i);
            assert!(found && idx == i, 0);
            i = i + 1;
        };
        destroy(v);
        test::end(scenario);
    }
}