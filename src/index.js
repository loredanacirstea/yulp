const nearley = require("nearley");
const Yulp = require('./yulplus');
const Yul = require('./yul');
const print = (v, isArr = Array.isArray(v)) => (isArr ? v : [v])
  .map(v => Array.isArray(v) ? print(v) : (!v ? '' : v.value)).join('');

function flatDeep(input) {
  const stack = [...input];
  const res = [];
  while(stack.length) {
    // pop value from stack
    const next = stack.pop();
    if(Array.isArray(next)) {
      // push back array items, won't modify the original input
      stack.push(...next);
    } else {
      res.push(next);
    }
  }
  // reverse to restore input order
  return res.reverse();
}

function _filter(arr, kind, prop = 'type', stopKind = 'Nothing') {
  var isStopKind = false;

  return flatDeep(arr, 10000000)
    .filter(v => {
      if (v[prop] === stopKind) {
        isStopKind = true;
      }

      if (isStopKind === true) {
        return false;
      }

      return v[prop] === kind;
    });
}

// Export parser
module.exports = {
  nearley,
  Yulp,
  compile: source => {
    const parser = new nearley.Parser(Yulp);
    const result = parser.feed(source);

    const signatures = _filter(result.results, true, 'isSignature')
      .map(v => ({ abi: v.signature, signature: v.value }));
    const topics = _filter(result.results, true, 'isTopic')
      .map(v => ({ abi: v.topic, topic: v.value }));

    result.signatures = signatures;
    result.topics = topics;

    return result;
  },
  print,
};
