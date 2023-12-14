import { makeFile } from './make-csv';

makeFile(2300).then(() => {
  console.log('done');
});
