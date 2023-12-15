#[test_only]
module suitears::merkle_proof_tests {
  use sui::test_utils::assert_eq;
  
  use suitears::merkle_proof::{verify, verify_with_index};

  #[test]
  fun test_verify() {
    let proof = vector[
      x"521ec18851e17bbba961bc46c70baf03ee67ebdea11a8306de39c15a90e9d2e5",
      x"8aa5d28b6ad4365d6b18f58b34fd9d6c1f9b5b830c7ba40d42175835088e1926",
      x"dd7bae5904a09a9ffb8a54e360a1f7a71de53dfbfee7776995909716627ef949",
      x"fa463ec4701e11a4b3b92c2d97f590931f870d5e98a5e304bd79b7f7fb262c63",
      x"cd0c0ee75d17e89ead6a2dedefc1d50f6a63a989f30ffe7965f477438ffe2b83",
      x"8581393ada8ba3187514cf0a30e3ccae54b024d05eacb31e5d3e49a45a8082a8",
      x"ef95447405babdf85baa7c4f0059e687df4e4ff1dfb90f62be64d406301e4317"
    ];

    let root = x"d5852c8cb4936ab82010fafae6015d1975349c15ae06acb79c1cf95bbbbd4e23";
    let leaf = x"1c9ebd6caf02840a5b2b7f0fc870ec1db154886ae9fe621b822b14fd0bf513d6";
    assert_eq(verify(&proof, root, leaf), true);

    let proof = vector[
      x"1c9ebd6caf02840a5b2b7f0fc870ec1db154886ae9fe621b822b14fd0bf513d6",
      x"8aa5d28b6ad4365d6b18f58b34fd9d6c1f9b5b830c7ba40d42175835088e1926",
      x"dd7bae5904a09a9ffb8a54e360a1f7a71de53dfbfee7776995909716627ef949",
      x"fa463ec4701e11a4b3b92c2d97f590931f870d5e98a5e304bd79b7f7fb262c63",
      x"cd0c0ee75d17e89ead6a2dedefc1d50f6a63a989f30ffe7965f477438ffe2b83",
      x"8581393ada8ba3187514cf0a30e3ccae54b024d05eacb31e5d3e49a45a8082a8",
      x"ef95447405babdf85baa7c4f0059e687df4e4ff1dfb90f62be64d406301e4317"

    ];
    let leaf = x"521ec18851e17bbba961bc46c70baf03ee67ebdea11a8306de39c15a90e9d2e5";
    assert_eq(verify(&proof, root, leaf), true);
  }

  #[test]
  fun test_verify_with_index() {
    let proof = vector[
      x"521ec18851e17bbba961bc46c70baf03ee67ebdea11a8306de39c15a90e9d2e5",
      x"8aa5d28b6ad4365d6b18f58b34fd9d6c1f9b5b830c7ba40d42175835088e1926",
      x"dd7bae5904a09a9ffb8a54e360a1f7a71de53dfbfee7776995909716627ef949",
      x"fa463ec4701e11a4b3b92c2d97f590931f870d5e98a5e304bd79b7f7fb262c63",
      x"cd0c0ee75d17e89ead6a2dedefc1d50f6a63a989f30ffe7965f477438ffe2b83",
      x"8581393ada8ba3187514cf0a30e3ccae54b024d05eacb31e5d3e49a45a8082a8",
      x"ef95447405babdf85baa7c4f0059e687df4e4ff1dfb90f62be64d406301e4317"
    ];

    let root = x"d5852c8cb4936ab82010fafae6015d1975349c15ae06acb79c1cf95bbbbd4e23";
    let leaf = x"1c9ebd6caf02840a5b2b7f0fc870ec1db154886ae9fe621b822b14fd0bf513d6";

    let (pred, index) = verify_with_index(&proof, root, leaf);   
    assert_eq(pred, true);
    assert_eq(index, 2);

    let proof = vector[
      x"1c9ebd6caf02840a5b2b7f0fc870ec1db154886ae9fe621b822b14fd0bf513d6",
      x"8aa5d28b6ad4365d6b18f58b34fd9d6c1f9b5b830c7ba40d42175835088e1926",
      x"dd7bae5904a09a9ffb8a54e360a1f7a71de53dfbfee7776995909716627ef949",
      x"fa463ec4701e11a4b3b92c2d97f590931f870d5e98a5e304bd79b7f7fb262c63",
      x"cd0c0ee75d17e89ead6a2dedefc1d50f6a63a989f30ffe7965f477438ffe2b83",
      x"8581393ada8ba3187514cf0a30e3ccae54b024d05eacb31e5d3e49a45a8082a8",
      x"ef95447405babdf85baa7c4f0059e687df4e4ff1dfb90f62be64d406301e4317"

    ];
    let leaf = x"521ec18851e17bbba961bc46c70baf03ee67ebdea11a8306de39c15a90e9d2e5";
    let (pred, index2) = verify_with_index(&proof, root, leaf);
    assert_eq(index2, 66);   
    assert_eq(pred, true);
    assert_eq(index != index2, true);
    assert_eq(index2 >  index, true);
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
      x"b039179a8a4ce2c252aa6f2f25798251c19b75fc1508d9d511a191e0487d64a7",
      x"263ab762270d3b73d3e2cddf9acc893bb6bd41110347e5d5e4bd1d3c128ea90a"
    ];
    let root = x"d2c57229e0e7b9b837ebf512d2d8415c2acb5b7025498144960bec86b570a8d2";
    let leaf = x"80084bf2fba02475726feb2cab2d8215eab14bc6bdd8bfb2c8151257032ecd8b";
    assert_eq(verify(&proof, root, leaf), false);
  }

  #[test]
  fun test_verify_bad_leaf() {
   let proof = vector[
      x"b039179a8a4ce2c252aa6f2f25798251c19b75fc1508d9d511a191e0487d64a7",
      x"263ab762270d3b73d3e2cddf9acc893bb6bd41110347e5d5e4bd1d3c128ea90a"
    ];
    let root = x"d97d99ede070cf7d31e58fcd5421d7e380d4512946c1feed44df378cf2e70791";
    let leaf = x"4ce8765e720c576f6f5a34ca380b3de5f0912e6e3cc5355542c363891e54594b";
    assert_eq(verify(&proof, root, leaf), false);
  }
}