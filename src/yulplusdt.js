import fs from 'fs';
import yaml from 'yaml';
import { utils } from 'ethers';
import { abiBuildSigsTopics, abiToStr } from './abiextract.js';

const dtypeSample = yaml.parse(fs.readFileSync('./src/dtypes.yml', 'utf8'));
let dtypes = {};

const dtypeName = dtype => dtype.type + (dtype.size || '');
const dtypeId = dtypeName;
const getById = dtypeid => dtypes[dtypeid];
const size = (dtype) => {
  switch(dtype.type_choice) {
    case 0:
      return dtype.size;
    case 1:
      return dtype.size * sizeById(dtype.inputs[0].type);
    case 2:
      return sizeById(dtype.inputs[0].type);
    default:
      return dtype.size;
  }
}
const sizeById = dtypeid => {
  const dtype = getById(dtypeid);
  return size(dtype);
}

const sizeBytes = dtype => {
  return Math.ceil(size(dtype) / 8);
}

const stringToSig = str =>  {
  const abi = abiBuildSigsTopics([str.slice(2)]);
  // TODO check if abi types are dtypes
  const sigStr = abiToStr(abi[0]);
  return utils.id(sigStr).slice(0, 10);
}

dtypeSample.forEach(dtype => dtypes[dtypeName(dtype)] = dtype);
console.log('dtypes', dtypes);
module.exports = {
  dtypes,
  dtypeutils: {
    getById,
    size,
    sizeById,
    sizeBytes,
    stringToSig,
  }
}
