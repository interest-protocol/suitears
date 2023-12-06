#[test_only]
module suitears::merkle_proof_tests {
  use sui::test_utils::assert_eq;
  
  use suitears::merkle_proof::{verify, multi_proof_verify};

  #[test]
  fun test_verify() {
    // Check utils/src/merkle-proof.ts
    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/test/utils/cryptography/MerkleProof.test.js
    let proof = vector[
      x"7051e21dd45e25ed8c605a53da6f77de151dcbf47b0e3ced3c5d8b61f4a13dbc",
      x"1629d3b5b09b30449d258e35bbd09dd5e8a3abb91425ef810dc27eef995f7490",
      x"633d21baee4bbe5ed5c51ac0c68f7946b8f28d2937f0ca7ef5e1ea9dbda52e7a",
      x"8a65d3006581737a3bab46d9e4775dbc1821b1ea813d350a13fcd4f15a8942ec",
      x"d6c3f3e36cd23ba32443f6a687ecea44ebfe2b8759a62cccf7759ec1fb563c76",
      x"276141cd72b9b81c67f7182ff8a550b76eb96de9248a3ec027ac048c79649115",                              
    ];


    let root = x"b89eb120147840e813a77109b44063488a346b4ca15686185cf314320560d3f3";
    let leaf = x"6efbf77e320741a027b50f02224545461f97cd83762d5fbfeb894b9eb3287c16";
    assert_eq(verify(&proof, root, leaf), true);


    let proof = vector[
      x"1629d3b5b09b30449d258e35bbd09dd5e8a3abb91425ef810dc27eef995f7490",
      x"633d21baee4bbe5ed5c51ac0c68f7946b8f28d2937f0ca7ef5e1ea9dbda52e7a",
      x"8a65d3006581737a3bab46d9e4775dbc1821b1ea813d350a13fcd4f15a8942ec",
      x"d6c3f3e36cd23ba32443f6a687ecea44ebfe2b8759a62cccf7759ec1fb563c76",
      x"276141cd72b9b81c67f7182ff8a550b76eb96de9248a3ec027ac048c79649115",                              
    ];
    let leaf = x"a68bdd3859f39d4723bb3e83e33ae8205e6c8004c7df8a420db5f84280f63ba0";
    assert_eq(verify(&proof, root, leaf), true);
  }

  #[test]
  fun test_verify_bad_proof() {
    // Proof from a different tree
    let proof = vector[x"7b0c6cd04b82bfc0e250030a5d2690c52585e0cc6a4f3bc7909d7723b0236ece"];
    let root = x"f2129b5a697531ef818f644564a6552b35c549722385bc52aa7fe46c0b5f46b1";
    let leaf = x"9c15a6a0eaeed500fd9eed4cbeab71f797cefcc67bfd46683e4d2e6ff7f06d1c";
    assert_eq(verify(&proof, root, leaf), false);
  }

  #[test]
  fun test_verify_bad_root() {
    let proof = vector[
      x"19ba6c6333e0e9a15bf67523e0676e2f23eb8e574092552d5e888c64a4bb3681",
      x"9cf5a63718145ba968a01c1d557020181c5b252f665cf7386d370eddb176517b"
    ];
    let root = x"736a8b2b04d5e692a88f2d85a89b2c821bd69e2a6d58fbc6c789bdb94c86da41";
    let leaf = x"9c15a6a0eaeed500fd9eed4cbeab71f797cefcc67bfd46683e4d2e6ff7f06d1c";
    assert_eq(verify(&proof, root, leaf), false);
  }

  #[test]
  fun test_verify_bad_leaf() {
    let proof = vector[
      x"19ba6c6333e0e9a15bf67523e0676e2f23eb8e574092552d5e888c64a4bb3681",
      x"9cf5a63718145ba968a01c1d557020181c5b252f665cf7386d370eddb176517b"
    ];
    let root = x"f2129b5a697531ef818f644564a6552b35c549722385bc52aa7fe46c0b5f46b1";
    let leaf = x"eba909cf4bb90c6922771d7f126ad0fd11dfde93f3937a196274e1ac20fd2f5b";
    assert_eq(verify(&proof, root, leaf), false);
  }

  #[test]
  fun test_multi_proof_verify() {
    let root = x"6deb52b5da8fd108f79fab00341f38d2587896634c646ee52e49f845680a70c8";
    let proof_flags = vector[false, true, false, true];
    let leaves = vector[
      x"19ba6c6333e0e9a15bf67523e0676e2f23eb8e574092552d5e888c64a4bb3681",
      x"c62a8cfa41edc0ef6f6ae27a2985b7d39c7fea770787d7e104696c6e81f64848",
      x"eba909cf4bb90c6922771d7f126ad0fd11dfde93f3937a196274e1ac20fd2f5b"
    ];
    let proof =  vector[
      x"9a4f64e953595df82d1b4f570d34c4f4f0cfaf729a61e9d60e83e579e1aa283e",
      x"8076923e76cf01a7c048400a2304c9a9c23bbbdac3a98ea3946340fdafbba34f"
    ];

    assert_eq(multi_proof_verify(&proof, &proof_flags, root, &leaves), true);
  }  

  #[test]
  fun test_multi_proof_verify_empty_proof() {
    let root = x"6deb52b5da8fd108f79fab00341f38d2587896634c646ee52e49f845680a70c8";
    let proof_flags = vector[true, true];
    let leaves = vector[
      x"34e6ce3d0d73f6bff2ee1e865833d58e283570976d70b05f45c989ef651ef742",
      x"aa28358fb75b314c899e16d7975e029d18b4457fd8fd831f2e6c17ffd17a1d7e",
      x"e0fd7e6916ff95d933525adae392a17e247819ebecc2e63202dfec7005c60560"
    ];
    let proof =  vector[];    
    assert_eq(multi_proof_verify(&proof, &proof_flags, root, &leaves), false);
  }

  #[test]
  #[expected_failure(abort_code = suitears::merkle_proof::EInvalidMultiProof)]
  fun test_multi_proof_verify_error() {
    let root = x"8f7234e8cfe39c08ca84a3a3e3274f574af26fd15165fe29e09cbab742daccd9";
    let proof_flags = vector[false, false, false];
    let leaves = vector[
      x"19ba6c6333e0e9a15bf67523e0676e2f23eb8e574092552d5e888c64a4bb3681",
      x"9a4f64e953595df82d1b4f570d34c4f4f0cfaf729a61e9d60e83e579e1aa283e"
    ];
    let proof =  vector[
      x"19ba6c6333e0e9a15bf67523e0676e2f23eb8e574092552d5e888c64a4bb3681", 
      x"58ed0d8354dd14fce77cba278da20ef4b8baabbc12868158322dfd004b2f46d3",
      x"03707d7802a71ca56a8ad8028da98c4f1dbec55b31b4a25d536b5309cc20eda9"
    ];   
    multi_proof_verify(&proof, &proof_flags, root, &leaves);    
  }

  #[test]
  fun test_multi_proof_verify_empty_leaves() {
    let root = x"6deb52b5da8fd108f79fab00341f38d2587896634c646ee52e49f845680a70c8";
    assert_eq(multi_proof_verify(&vector[root], &vector[], root, &vector[]), true);
  }

  #[test]
  fun test_multi_proof_verify_one_leaf_tree() {
    let root = x"9c15a6a0eaeed500fd9eed4cbeab71f797cefcc67bfd46683e4d2e6ff7f06d1c";
    let proof_flags = vector[];
    let leaves = vector[root];
    let proof =  vector[];   
     assert_eq(multi_proof_verify(&proof, &proof_flags, root, &leaves), true);
  }

  #[test]
  #[expected_failure]
  fun test_multi_proof_verify_error_2() {
    let root = x"8f7234e8cfe39c08ca84a3a3e3274f574af26fd15165fe29e09cbab742daccd9";
    let proof_flags = vector[false, false, false, false];
    let leaves = vector[
      x"19ba6c6333e0e9a15bf67523e0676e2f23eb8e574092552d5e888c64a4bb3681",
      x"9a4f64e953595df82d1b4f570d34c4f4f0cfaf729a61e9d60e83e579e1aa283e"
    ];
    let proof =  vector[
      x"19ba6c6333e0e9a15bf67523e0676e2f23eb8e574092552d5e888c64a4bb3681", 
      x"58ed0d8354dd14fce77cba278da20ef4b8baabbc12868158322dfd004b2f46d3",
      x"03707d7802a71ca56a8ad8028da98c4f1dbec55b31b4a25d536b5309cc20eda9"
    ];   
    multi_proof_verify(&proof, &proof_flags, root, &leaves);    
  }  

  #[test]
  #[expected_failure]
  fun test_multi_proof_verify_malicious_proofs() {
    let root = x"f2d552e1e4c59d4f0fa2b80859febc9e4bdc915dff37c56c858550d8b64659a5";
    let proof_flags = vector[true, true, false];
    let leaves = vector[
      x"1f23ad5fc0ee6ccbe2f3d30df856758f05ad9d03408a51a99c1c9f0854309db2",
      x"613994f4e324d0667c07857cd5d147994bc917da5d07ee63fc3f0a1fe8a18e34"
    ];
    let proof =  vector[
      x"5e941ddd8f313c0b39f92562c0eca709c3d91360965d396aaef584b3fa76889a", 
      x"5e941ddd8f313c0b39f92562c0eca709c3d91360965d396aaef584b3fa76889a",
    ];   
    multi_proof_verify(&proof, &proof_flags, root, &leaves);        
  }

}