import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { ethers } from 'ethers';

import { bcs } from '@mysten/sui.js/bcs';

export const createTree = () => {
  const ADDRESS_ONE =
    '0x94fbcf49867fd909e6b2ecf2802c4b2bba7c9b2d50a13abbb75dbae0216db82a';

  const AMOUNT_ONE = 55;

  const ADDRESS_TWO =
    '0xb4536519beaef9d9207af2b5f83ae35d4ac76cc288ab9004b39254b354149d27';

  const AMOUNT_TWO = 27;

  const DATA_ONE = Buffer.concat([
    Buffer.from(bcs.ser(bcs.Address.name, ADDRESS_ONE).toBytes()),
    Buffer.from(bcs.ser(bcs.u64.name, AMOUNT_ONE).toBytes()),
  ]);

  const DATA_TWO = Buffer.concat([
    Buffer.from(bcs.ser(bcs.Address.name, ADDRESS_TWO).toBytes()),
    Buffer.from(bcs.ser(bcs.u64.name, AMOUNT_TWO).toBytes()),
  ]);

  const leaves = [DATA_ONE, DATA_TWO].map((x) => [ethers.keccak256(x)]);

  const merkleTree = StandardMerkleTree.of(leaves, ['string']);

  const root = merkleTree.root;
  const hashOne = merkleTree.leafHash(leaves[0]);
  const hashTwo = merkleTree.leafHash(leaves[1]);
  const proofOne = merkleTree.getProof(leaves[0]);
  const proofTwo = merkleTree.getProof(leaves[1]);

  console.log({
    root,
    hashOne,
    hashTwo,
    proofOne,
    proofTwo,
  });
};
