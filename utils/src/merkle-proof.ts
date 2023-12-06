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

export const multiProofVerify = () => {
  const merkleTree = StandardMerkleTree.of(toElements('abcdef'), ['string']);

  const root = merkleTree.root;
  const { proof, proofFlags, leaves } = merkleTree.getMultiProof(
    toElements('bdf'),
  );
  const hashes = leaves.map((e) => merkleTree.leafHash(e));

  console.log({
    root,
    proofFlags,
    hashes,
    proof,
  });
};

export const invalidMultiProofVerify = () => {
  const merkleTree = StandardMerkleTree.of(toElements('abcdef'), ['string']);
  const otherMerkleTree = StandardMerkleTree.of(toElements('ghi'), ['string']);

  const root = merkleTree.root;
  const { proof, proofFlags, leaves } = otherMerkleTree.getMultiProof(
    toElements('ghi'),
  );
  const hashes = leaves.map((e) => merkleTree.leafHash(e));

  console.log({
    proof,
    proofFlags,
    root,
    hashes,
  });
};

export const revertMultiProofCaseOne = () => {
  const merkleTree = StandardMerkleTree.of(toElements('abcd'), ['string']);

  const root = merkleTree.root;
  const hashA = merkleTree.leafHash(['a']);
  const hashB = merkleTree.leafHash(['b']);
  const hashCD = hashPair(
    ethers.toBeArray(merkleTree.leafHash(['c'])),
    ethers.toBeArray(merkleTree.leafHash(['d'])),
  );
  const hashE = merkleTree.leafHash(['e']); // incorrect (not part of the tree)
  const fill = ethers.randomBytes(32);

  console.log({
    root,
    hashA,
    hashB,
    hashCD,
    hashE,
    fill: Buffer.from(fill).toString('hex'),
  });
};

export const revertMaliciousData = () => {
  // Create a merkle tree that contains a zero leaf at depth 1
  const leave = ethers.id('real leaf');
  const root = hashPair(ethers.toBeArray(leave), Buffer.alloc(32, 0));

  // Now we can pass any **malicious** fake leaves as valid!
  const maliciousLeaves = ['malicious', 'leaves']
    .map(ethers.id)
    .map(ethers.toBeArray)
    .sort(Buffer.compare);
  const maliciousProof = [leave, leave];
  const maliciousProofFlags = [true, true, false];

  console.log({
    leave,
    root,
    maliciousLeaves: maliciousLeaves.map((x) => Buffer.from(x).toString('hex')),
    maliciousProof,
    maliciousProofFlags,
  });
};

export const treeWithOneLeaf = () => {
  const merkleTree = StandardMerkleTree.of(toElements('a'), ['string']);

  const root = merkleTree.root;
  const { proof, proofFlags, leaves } = merkleTree.getMultiProof(
    toElements('a'),
  );
  const hashes = leaves.map((e) => merkleTree.leafHash(e));

  console.log({
    root,
    hashes,
    proof,
    proofFlags,
    leaves,
  });
};
