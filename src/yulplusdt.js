import fs from 'fs';
import yaml from 'yaml';

const dtypeSample = yaml.parse(fs.readFileSync('./src/dtypes.yml', 'utf8'));
let dtypes = {};

const dtypeName = dtype => dtype.type + (dtype.size || '');
const dtypeId = dtypeName;
const getById = dtypeid => dtypes[dtypeid];
const size = (dtype) => {
  console.log('size', dtype);
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

dtypeSample.forEach(dtype => dtypes[dtypeName(dtype)] = dtype);
console.log('dtypes', dtypes);
module.exports = {
  dtypes,
  dtypeutils: {
    getById,
    size,
    sizeById,
    sizeBytes,
  }
}
