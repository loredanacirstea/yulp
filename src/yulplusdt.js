import fs from 'fs';
import yaml from 'yaml';
import { utils } from 'ethers';
import { abiBuildSigsTopics, abiToStr } from './abiextract.js';
import { dtypedefs } from './dtypes_yml.js';

const dtypeSample = yaml.parse(dtypedefs);
let dtypes = {};

const typeChoice = {
  basetype: 0,
  contig: 1,
  namedtype: 2,
  namedtuple: 3, // a type of contig, e.g. structs, named tuples - maybe we can abstract
  array: 4,  // if size => static arrays, else dynamic arrays
}
// 5: polimorphism / generics
// 6: derived type

// TODO: contigs(T) ? also be named as arrays, with T's name included
// simple names -> abstractions or aliases

const defaultTypeName = dtype => dtype.type + (dtype.size || '');
const customTypeName = {
  4: dtype => dtype.inputs[0].type + defaultTypeName(dtype),
}

const dtypeName = dtype => (customTypeName[dtype.type_choice] || defaultTypeName)(dtype);
const dtypeId = dtypeName;
const getById = dtypeid => dtypes[dtypeid];
const size = (dtype) => {
  if (typeof dtype === 'string') {
    dtype = getById(dtype);
  }

  switch(dtype.type_choice) {
    case typeChoice.basetype:
      return dtype.size;
    case typeChoice.contig:
      return dtype.size * size(dtype.inputs[0].type);
    case typeChoice.namedtype:
      return size(dtype.inputs[0].type);
    case typeChoice.namedtuple:
      return dtype.inputs.map(inp => size(inp.type)).reduce((sum, val) => sum + val);
    case typeChoice.array:
      // static array
      if (dtype.size) return dtype.size * size(dtype.inputs[0].type);

      // dynamic array
      return null;
    default:
      return dtype.size;
  }
}

const sizeBytes = dtype => {
  return Math.ceil(size(dtype) / 8);
}

const getByIdWithLength = dtypeid => {
  const dtype = getById(dtypeid);
  dtype.length = sizeBytes(dtype);
  if (dtype.type === 'array') {
    dtype.itemlength = sizeBytes(dtype.inputs[0].type);
  }
  return dtype;
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
    size,
    sizeBytes,
    getById,
    getByIdWithLength,
    stringToSig,
  }
}
