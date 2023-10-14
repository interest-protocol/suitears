// * IMPORTANT Use Smart Vector to create
// A vector that can scale forever
// Notive vector should not be used after 1000 entries
// Based from : https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/data_structures/big_vector.move
module suitears::big_vector {
    use std::vector;
    
    use sui::dynamic_field as df;
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    #[test_only]
    use sui::tx_context::dummy;
    #[test_only]
    use sui::test_scenario::{Self as test, ctx};
    
    // friend aptos_std::smart_vector;

    /// Vector index is out of bounds
    const EIndexOutOfBounds: u64 = 1;
    const EVectorEmpty: u64 = 2;
    /// Cannot pop back from an empty vector
    const EVectorNotEmpty: u64 = 3;
    /// bucket_size cannot be 0
    const EZeroBucketSize: u64 = 4;

    /// A scalable vector implementation based on tables where elements are grouped into id.
    /// Each bucket has a capacity of `bucket_size` elements.
    struct BigVector<phantom T: store> has key, store {
        id: UID,
        end_index: u64,
        bucket_size: u64,
        length: u64
    }
    
    /// Regular Vector API

    /// Create an empty vector.
    public(friend) fun new<T: store>(bucket_size: u64, ctx: &mut TxContext): BigVector<T> {
        assert!(bucket_size > 0, EZeroBucketSize);
        BigVector {
            id: object::new(ctx),
            end_index: 0,
            bucket_size,
            length: 0
        }
    }

    /// Create a vector of length 1 containing the passed in element.
    public(friend) fun singleton<T: store>(element: T, bucket_size: u64, ctx: &mut TxContext): BigVector<T> {
        let v = new(bucket_size, ctx);
        push_back(&mut v, element);
        v
    }

    /// Destroy the vector `v`.
    /// Aborts if `v` is not empty.
    public fun destroy_empty<T: store>(v: BigVector<T>) {
        assert!(is_empty(&v), EVectorNotEmpty);
        let BigVector { id, end_index: _, bucket_size: _, length: _ } = v;
        object::delete(id);
    }

    /// Destroy the vector `v` if T has `drop`
    public fun destroy<T: store + drop>(v: BigVector<T>) {
        let BigVector { id, end_index, bucket_size: _, length: _ } = v;
        let i = 0;
        while (end_index > 0) {
            let num_elements = vector::length(&df::remove<u64, vector<T>>(&mut id, i));
            end_index = end_index - num_elements;
            i = i + 1;
        };
        object::delete(id);
    }

    /// Acquire an immutable reference to the `i`th element of the vector `v`.
    /// Aborts if `i` is out of bounds.
    public fun borrow<T: store>(v: &BigVector<T>, i: u64): &T {
        assert!(i < length(v), EIndexOutOfBounds);
        vector::borrow(df::borrow(&v.id, i / v.bucket_size), i % v.bucket_size)
    }

    /// Return a mutable reference to the `i`th element in the vector `v`.
    /// Aborts if `i` is out of bounds.
    public fun borrow_mut<T: store>(v: &mut BigVector<T>, i: u64): &mut T {
        assert!(i < length(v), EIndexOutOfBounds);
        vector::borrow_mut(df::borrow_mut(&mut v.id, i / v.bucket_size), i % v.bucket_size)
    }

    /// Empty and destroy the other vector, and push each of the elements in the other vector onto the lhs vector in the
    /// same order as they occurred in other.
    /// Disclaimer: This function is costly. Use it at your own discretion.
    public fun append<T: store>(lhs: &mut BigVector<T>, other: BigVector<T>) {
        let other_len = length(&other);
        let half_other_len = other_len / 2;
        let i = 0;
        while (i < half_other_len) {
            push_back(lhs, swap_remove(&mut other, i));
            i = i + 1;
        };
        while (i < other_len) {
            push_back(lhs, pop_back(&mut other));
            i = i + 1;
        };
        destroy_empty(other);
    }

    /// Add element `val` to the end of the vector `v`. It grows the id when the current id are full.
    /// This operation will cost more gas when it adds new bucket.
    public fun push_back<T: store>(v: &mut BigVector<T>, val: T) {
        let num_buckets = v.length;
        if (v.end_index == num_buckets * v.bucket_size) {
            add(v, num_buckets, vector[val]);
        } else {
            vector::push_back(df::borrow_mut(&mut v.id, num_buckets - 1), val);
        };
        v.end_index = v.end_index + 1;
    }

    /// Pop an element from the end of vector `v`. It doesn't shrink the id even if they're empty.
    /// Call `shrink_to_fit` explicity to deallocate empty id.
    /// Aborts if `v` is empty.
    public fun pop_back<T: store>(v: &mut BigVector<T>): T {
        assert!(!is_empty(v), EVectorEmpty);
        let num_buckets = v.length;
        let last_bucket = df::borrow_mut<u64, vector<T>>(&mut v.id, num_buckets - 1);
        let val = vector::pop_back(last_bucket);
        // Shrink the table if the last vector is empty.
        if (vector::is_empty(last_bucket)) {
            vector::destroy_empty(df_remove(v, num_buckets - 1));
        };
        v.end_index = v.end_index - 1;
        val
    }

    /// Remove the element at index i in the vector v and return the owned value that was previously stored at i in v.
    /// All elements occurring at indices greater than i will be shifted down by 1. Will abort if i is out of bounds.
    /// Disclaimer: This function is costly. Use it at your own discretion.
    public fun remove<T:store>(v: &mut BigVector<T>, i: u64): T {
        let len = length(v);
        assert!(i < len, EIndexOutOfBounds);
        let num_buckets = v.length;
        let cur_bucket_index = i / v.bucket_size + 1;
        let cur_bucket = df::borrow_mut<u64, vector<T>>(&mut v.id, cur_bucket_index - 1);
        let res = vector::remove(cur_bucket, i % v.bucket_size);
        v.end_index = v.end_index - 1;

        while (cur_bucket_index < num_buckets) {
            // remove one element from the start of current vector
            let cur_bucket = df::borrow_mut<u64, vector<T>>(&mut v.id, cur_bucket_index);
            let t = vector::remove(cur_bucket, 0);
  
            // and put it at the end of the last one
            let prev_bucket = df::borrow_mut<u64, vector<T>>(&mut v.id, cur_bucket_index - 1);
            vector::push_back(prev_bucket, t);
            cur_bucket_index = cur_bucket_index + 1;
        };
        spec {
            assert cur_bucket_index == num_buckets;
        };

        // Shrink the table if the last vector is empty.
        let last_bucket = df::borrow_mut<u64, vector<T>>(&mut v.id, num_buckets - 1);
        if (vector::is_empty(last_bucket)) {
            vector::destroy_empty(df_remove<T>(v, num_buckets - 1));
        };

        res
    }

    /// Swap the `i`th element of the vector `v` with the last element and then pop the vector.
    /// This is O(1), but does not preserve ordering of elements in the vector.
    /// Aborts if `i` is out of bounds.
    public fun swap_remove<T: store>(v: &mut BigVector<T>, i: u64): T {
        assert!(i < length(v), EIndexOutOfBounds);
        let last_val = pop_back(v);
        // if the requested value is the last one, return it
        if (v.end_index == i) {
            return last_val
        };
        // because the lack of mem::swap, here we swap remove the requested value from the bucket
        // and append the last_val to the bucket then swap the last bucket val back
        let bucket = df::borrow_mut<u64, vector<T>>(&mut v.id, i / v.bucket_size);
        let bucket_len = vector::length(bucket);
        let val = vector::swap_remove(bucket, i % v.bucket_size);
        vector::push_back(bucket, last_val);
        vector::swap(bucket, i % v.bucket_size, bucket_len - 1);
        val
    }

    /// Swap the elements at the i'th and j'th indices in the vector v. Will abort if either of i or j are out of bounds
    /// for v.
    public fun swap<T: store>(v: &mut BigVector<T>, i: u64, j: u64) {
        assert!(i < length(v) && j < length(v), EIndexOutOfBounds);
        let i_bucket_index = i / v.bucket_size;
        let j_bucket_index = j / v.bucket_size;
        let i_vector_index = i % v.bucket_size;
        let j_vector_index = j % v.bucket_size;
        if (i_bucket_index == j_bucket_index) {
            vector::swap(df::borrow_mut<u64, vector<T>>(&mut v.id, i_bucket_index), i_vector_index, j_vector_index);
            return
        };
        // If i and j are in different id, take the id out first for easy mutation.
        let bucket_i = df_remove<T>(v, i_bucket_index);
        let bucket_j = df_remove<T>(v, j_bucket_index);
        // Get the elements from id by calling `swap_remove`.
        let element_i = vector::swap_remove(&mut bucket_i, i_vector_index);
        let element_j = vector::swap_remove(&mut bucket_j, j_vector_index);
        // Swap the elements and push back to the other bucket.
        vector::push_back(&mut bucket_i, element_j);
        vector::push_back(&mut bucket_j, element_i);
        let last_index_in_bucket_i = vector::length(&bucket_i) - 1;
        let last_index_in_bucket_j = vector::length(&bucket_j) - 1;
        // Re-position the swapped elements to the right index.
        vector::swap(&mut bucket_i, i_vector_index, last_index_in_bucket_i);
        vector::swap(&mut bucket_j, j_vector_index, last_index_in_bucket_j);
        // Add back the id.
        add(v, i_bucket_index, bucket_i);
        add(v, j_bucket_index, bucket_j);
    }

    /// Reverse the order of the elements in the vector v in-place.
    /// Disclaimer: This function is costly. Use it at your own discretion.
    public fun reverse<T: store>(v: &mut BigVector<T>) {
        let new_buckets = vector<vector<T>>[];
        let push_bucket = vector<T>[];
        let num_buckets = v.length;
        let num_buckets_left = num_buckets;

        while (num_buckets_left > 0) {
            let pop_bucket = df_remove<T>(v, num_buckets_left - 1);
            let len = vector::length(&pop_bucket);
            
            while (len > 0) {
                let val = vector::pop_back(&mut pop_bucket);
                vector::push_back(&mut push_bucket, val);
                if (vector::length(&push_bucket) == v.bucket_size) {
                    vector::push_back(&mut new_buckets, push_bucket);
                    push_bucket = vector[];
                };
                len = len - 1;
            };
            vector::destroy_empty(pop_bucket);
            num_buckets_left = num_buckets_left - 1;
        };

        if (vector::length(&push_bucket) > 0) {
            vector::push_back(&mut new_buckets, push_bucket);
        } else {
            vector::destroy_empty(push_bucket);
        };

        vector::reverse(&mut new_buckets);
        let i = 0;
        assert!(v.length == 0, 0);
        while (i < num_buckets) {
            add(v, i, vector::pop_back(&mut new_buckets));
            i = i + 1;
        };
        vector::destroy_empty(new_buckets);
    }

    /// Return the index of the first occurrence of an element in v that is equal to e. Returns (true, index) if such an
    /// element was found, and (false, 0) otherwise.
    /// Disclaimer: This function is costly. Use it at your own discretion.
    public fun index_of<T: store>(v: &BigVector<T>, val: &T): (bool, u64) {
        let num_buckets = v.length;
        let bucket_index = 0;
        while (bucket_index < num_buckets) {
            let cur = df::borrow(&v.id, bucket_index);
            let (found, i) = vector::index_of(cur, val);
            if (found) {
                return (true, bucket_index * v.bucket_size + i)
            };
            bucket_index = bucket_index + 1;
        };
        (false, 0)
    }

    /// Return if an element equal to e exists in the vector v.
    /// Disclaimer: This function is costly. Use it at your own discretion.
    public fun contains<T: store>(v: &BigVector<T>, val: &T): bool {
        if (is_empty(v)) return false;
        let (exist, _) = index_of(v, val);
        exist
    }

    /// Convert a big vector to a native vector, which is supposed to be called mostly by view functions to get an
    /// atomic view of the whole vector.
    /// Disclaimer: This function may be costly as the big vector may be huge in size. Use it at your own discretion.
    public fun to_vector<T: copy + store>(v: &BigVector<T>): vector<T> {
        let res = vector[];
        let num_buckets = v.length;
        let i = 0;
        while (i < num_buckets) {
            vector::append(&mut res, *df::borrow(&v.id, i));
            i = i + 1;
        };
        res
    }

    /// Return the length of the vector.
    public fun length<T: store>(v: &BigVector<T>): u64 {
        v.end_index
    }

    /// Return `true` if the vector `v` has no elements and `false` otherwise.
    public fun is_empty<T: store>(v: &BigVector<T>): bool {
        length(v) == 0
    }

    fun add<T: store>(v: &mut BigVector<T>, k: u64, e: vector<T>) {
        df::add(&mut v.id, k, e);
        v.length = v.length + 1;
    }

    fun df_remove<T: store>(v: &mut BigVector<T>, k: u64): vector<T> {
        let val = df::remove(&mut v.id, k);
        v.length = v.length - 1;
        val
    }

    #[test]
    fun big_vector_test() {
        let v = new(5, &mut dummy());
        let i = 0;
        while (i < 100) {
            push_back(&mut v, i);
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
            push_back(&mut v, i);
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
    }

    #[test]
    fun big_vector_append_edge_case_test() {
        let v1 = new(5, &mut dummy());
        let v2 = singleton(1u64, 7, &mut dummy());
        let v3 = new(6, &mut dummy());
        let v4 = new(8, &mut dummy());
        append(&mut v3, v4);
        assert!(length(&v3) == 0, 0);
        append(&mut v2, v3);
        assert!(length(&v2) == 1, 0);
        append(&mut v1, v2);
        assert!(length(&v1) == 1, 0);
        destroy(v1);
    }

    #[test]
    fun big_vector_append_test() {
        let scenario = test::begin(@0x1);
        let test = &mut scenario;

        let v1 = new(5, ctx(test));
        let v2 = new(7, ctx(test));
        let i = 0;
        while (i < 7) {
            push_back(&mut v1, i);
            i = i + 1;
        };
        while (i < 25) {
            push_back(&mut v2, i);
            i = i + 1;
        };
        append(&mut v1, v2);
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
    fun big_vector_to_vector_test() {
        let v1 = new(7, &mut dummy());
        let i = 0;
        while (i < 100) {
            push_back(&mut v1, i);
            i = i + 1;
        };
        let v2 = to_vector(&v1);
        let j = 0;
        while (j < 100) {
            assert!(*vector::borrow(&v2, j) == j, 0);
            j = j + 1;
        };
        destroy(v1);
    }

    #[test]
    fun big_vector_remove_and_reverse_test() {
        let v = new(11, &mut dummy());
        let i = 0;
        while (i < 101) {
            push_back(&mut v, i);
            i = i + 1;
        };
        remove(&mut v, 100);
        remove(&mut v, 90);
        remove(&mut v, 80);
        remove(&mut v, 70);
        remove(&mut v, 60);
        remove(&mut v, 50);
        remove(&mut v, 40);
        remove(&mut v, 30);
        remove(&mut v, 20);
        remove(&mut v, 10);
        remove(&mut v, 0);
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
    }

    #[test]
    fun big_vector_swap_test() {
        let v = new(11, &mut dummy());
        let i = 0;
        while (i < 101) {
            push_back(&mut v, i);
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
    }

    #[test]
    fun big_vector_index_of_test() {
        let v = new(11, &mut dummy());
        let i = 0;
        while (i < 100) {
            push_back(&mut v, i);
            let (found, idx) = index_of(&mut v, &i);
            assert!(found && idx == i, 0);
            i = i + 1;
        };
        destroy(v);
    }

    #[test]
    fun big_vector_empty_contains() {
        let v = new(10, &mut dummy());
        assert!(!contains<u64>(&v, &(1 as u64)), 0);
        destroy_empty(v);
    }
}