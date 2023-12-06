import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { ethers } from 'ethers';

const toElements = (str: string) => str.split('').map((e) => [e]);
const hashPair = (a: Uint8Array, b: Uint8Array) =>
  ethers.keccak256(Buffer.concat([a, b].sort(Buffer.compare)));

export const validVerify = () => {
  const merkleTree = StandardMerkleTree.of(
    toElements(
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=',
    ),
    ['string'],
  );

  const root = merkleTree.root;
  const hash = merkleTree.leafHash(['A']);
  const proof = merkleTree.getProof(['A']);

  const noSuchLeaf = hashPair(
    ethers.toBeArray(merkleTree.leafHash(['A'])),
    ethers.toBeArray(merkleTree.leafHash(['B'])),
  );

  console.log({
    root,
    hash,
    proof,
    noSuchLeaf,
  });
};

export const invalidVerify = () => {
  const correctMerkleTree = StandardMerkleTree.of(toElements('abc'), [
    'string',
  ]);
  const otherMerkleTree = StandardMerkleTree.of(toElements('def'), ['string']);

  const root = correctMerkleTree.root;
  const hash = correctMerkleTree.leafHash(['a']);
  const rightProof = correctMerkleTree.getProof(['a']);
  const wrongProof = otherMerkleTree.getProof(['d']);
  const wrongRoot = otherMerkleTree.root;
  const wrongLeaf = otherMerkleTree.leafHash(['d']);

  console.log({
    root,
    hash,
    rightProof,
    wrongProof,
    wrongRoot,
    wrongLeaf,
  });
};
