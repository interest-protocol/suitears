import { promisify } from 'util';
import * as fs from 'fs';

import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';

const promiseWriteFile = promisify(fs.writeFile);
import path from 'path';
const randomPublicKey = () => {
  const keypair = new Ed25519Keypair();
  return keypair.getPublicKey().toSuiAddress();
};

const randomIntFromInterval = (min: number, max: number) =>
  Math.floor(Math.random() * (max - min + 1) + min);

const makeList = (size: number) => {
  let i = 0;
  let list = '';
  while (size > i) {
    list = list + ',' + `${randomPublicKey()},${randomIntFromInterval(2, 150)}`;
    i += 1;
  }

  return list;
};

export const makeFile = async (size: number) => {
  await promiseWriteFile(path.join(__dirname, './airdrop.csv'), makeList(size));
};
