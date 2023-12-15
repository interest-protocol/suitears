import { sha3_256 } from 'js-sha3';
import { MerkleTree } from 'merkletreejs';

const toElements = (str: string) => str.split('').map((e) => [e]);

export const validVerify = () => {
  const data = toElements(
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=',
  );

  const leaves = data.map((x) => sha3_256(x[0]));

  const tree = new MerkleTree(leaves, sha3_256, { sortPairs: true });
  const root = tree.getHexRoot();

  const hash = sha3_256(data[0][0]);
  const hashB = sha3_256(data[1][0]);
  const proof = tree.getHexProof(hash);
  const proofB = tree.getHexProof(hashB);

  const noSuchLeaf = sha3_256('noleaf');

  console.log({
    root,
    hash,
    hashB,
    proof,
    proofB,
    noSuchLeaf,
  });
};

export const invalidVerify = () => {
  const data = toElements('abc');
  const leaves = data.map((x) => sha3_256(x[0]));

  const correctMerkleTree = new MerkleTree(leaves, sha3_256, {
    sortPairs: true,
  });

  const data2 = toElements('def');
  const leaves2 = data2.map((x) => sha3_256(x[0]));

  const otherMerkleTree = new MerkleTree(leaves2, sha3_256, {
    sortPairs: true,
  });

  const root = correctMerkleTree.getHexRoot();
  const hash = sha3_256(data[0][0]);

  const rightProof = correctMerkleTree.getHexProof(hash);

  const wrongLeaf = sha3_256(data2[0][0]);
  const wrongProof = otherMerkleTree.getHexProof(wrongLeaf);
  const wrongRoot = otherMerkleTree.getHexRoot();

  console.log({
    root,
    hash,
    rightProof,
    wrongProof,
    wrongRoot,
    wrongLeaf,
  });
};
