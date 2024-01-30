import { toHEX } from '@mysten/sui.js/utils';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import wallet from './wallet.json';

const keypair = Ed25519Keypair.fromSecretKey(new Uint8Array(wallet as any));

(async () => {
  try {
    //create Transaction Block.
    const txb = new TransactionBlock();
    //Split coins
    let [coin] = txb.splitCoins(txb.gas, [1000]);
    //Add a transferObject transaction
    txb.transferObjects([coin, txb.gas], to);
    let txid = await client.signAndExecuteTransactionBlock({
      signer: keypair,
      transactionBlock: txb,
    });
    console.log(`Success! Check our your TX here:
        https://suiexplorer.com/txblock/${txid.digest}?network=devnet`);
  } catch (e) {
    console.error(`Oops, something went wrong: ${e}`);
  }
})();
