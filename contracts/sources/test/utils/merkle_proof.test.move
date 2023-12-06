#[test_only]
module suitears::merkle_proof_tests {

  // #[test]
  // fun test_verify() {
  //   let proof = vector::empty<vector<u8>>();
  //   vector::push_back(&mut proof, x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624");
  //   let root = x"59d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace";
  //   let leaf = x"45db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5";
  //   assert!(verify(&proof, root, leaf), 0);
  // }

  // #[test]
  // fun test_verify_bad_proof() {
  //   let proof = vector::empty<vector<u8>>();
  //   vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1349bbd7a0088d42c4acb73eeaed59c008d");
  //   let root = x"59d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace";
  //   let leaf = x"45db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5";
  //   assert!(!verify(&proof, root, leaf), 0);
  // }

  // #[test]
  // fun test_verify_bad_root() {
  //   let proof = vector::empty<vector<u8>>();
  //   vector::push_back(&mut proof, x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624");
  //   let root = x"58d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace";
  //   let leaf = x"45db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5";
  //   assert!(!verify(&proof, root, leaf), 0);
  // }

  // #[test]
  // fun test_verify_bad_leaf() {
  //   let proof = vector::empty<vector<u8>>();
  //   vector::push_back(&mut proof, x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624");
  //   let root = x"59d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace";
  //   let leaf = x"35db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5";
  //   assert!(!verify(&proof, root, leaf), 0);
  // }  
}