@{%
  const moo = require('moo')
  const { utils } = require('ethers');
  const clone = require('rfdc')() // Returns the deep copy function
  const { dtypeutils } = require('./yulplusdt.js')

  function id(x) { return x[0]; }

  const print = (v, isArr = Array.isArray(v)) => (isArr ? v : [v])
    .map(v => Array.isArray(v) ? print(v) : (!v ? '' : v.value)).join('');

  let lexer = moo.compile({
    space: { match: /\s+/, lineBreaks: true },
    singleLineComment: /\/\/.*?$/,
    multiComment: /\/\*[\s\S]*?\*\/|(?:[^\\:]|^)\/\/.*$/,
    NumberLiteral: /(?!0x)[0-9]+/,
    HexLiteral: /(?:hex)(?:"|')[0-9a-fA-F]+(?:"|')/,
    HexNumber: /0[x][0-9a-fA-F]+/,
    StringLiteral: /"(?:\\["bfnrt\/\\]|\\u[a-fA-F0-9]{4}|[^"\\])*"/,
    equate: ":=",
    "->": "->",
    ",": ",",
    ":": ":",
    MAX_UINTLiteral: /(?:MAX_UINT)/,
    SigLiteral: /(?:sig)"(?:\\["bfnrt\/\\]|\\u[a-fA-F0-9]{4}|[^"\\])*"/,
    DTSigLiteral: /(?:dtsig)"(?:\\["bfnrt\/\\]|\\u[a-fA-F0-9]{4}|[^"\\])*"/,
    DTypeAbiLiteral: /(?:abi)"(?:\\["bfnrt\/\\]|\\u[a-fA-F0-9]{4}|[^"\\])*"/,
    TopicLiteral: /(?:topic)"(?:\\["bfnrt\/\\]|\\u[a-fA-F0-9]{4}|[^"\\])*"/,
    codeKeyword: /(?:code)(?:\s)/,
    objectKeyword: /(?:object)(?:\s)/,
    dataKeyword: /(?:data)(?:\s)/,
    boolean: ["true", "false"],
    bracket: ["{", "}", "(", ")", '[', ']'],
    ConstIdentifier: /(?:const)(?:\s)/,
    keyword: ['code ', 'let', "for", "function", "enum", "mstruct", "dtmstruct", "if", "else", "break", "continue", "default", "switch", "case"],
    Identifier: /[\w.]+/,
  });

  function stringToSig(str) {
    const clean = str.trim();

    if (clean.indexOf("event") === 0) {
      const inter = new utils.Interface([str]);
      return inter.events[Object.keys(inter.events)[0]].topic;
    } else {
      const inter = new utils.Interface([str]);
      return inter.functions[Object.keys(inter.functions)[0]].sighash;
    }
  }

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

  function mapDeep(arr, f, d = 0) {
    return Array.isArray(arr) ? arr.map(v => mapDeep(v, f, d++)) : f(arr, d);
  }

  function _filter(arr, kind, stopKind = 'Nothing') {
    var isStopKind = false;

    return flatDeep(arr, 10000000)
      .filter(v => {
        if (v.type === stopKind) {
          isStopKind = true;
        }

        if (isStopKind === true) {
          return false;
        }

        return v.type === kind;
      });
  }

  function _filterKind(arr, kind, stopKind = null) {
    var isStopKind = false;

    return flatDeep(arr, 10000000)
      .filter(v => {
        if (v.kind === stopKind) {
          isStopKind = true;
        }

        if (isStopKind === true) {
          return false;
        }

        return v.kind === kind;
      });
  }

  const stateKind = kind => d => {
    d[0].kind = kind;
    return d;
  }

  function functionCall(d) {
    d[0].type = 'FunctionCallIdentifier';
    d[0].name = d[0].value;

    // if mstore(0, x, x, x) args, than process this..
    if (d[0].value === 'mstore' && d[2][3].length > 1) {
      // values after pos, x, [....]
      const secondaryValues = d[2][3].slice(1);

      // slice away the secondary values
      d[2][3] = d[2][3].slice(0, 1);

      // New injected mstores
      const firstMstoreArgument = print(d[2][2]);
      const additionalMstores = secondaryValues.map((v, i) => {

        const mstoreCopy = clone(d);
        const valOffset = (i + 1) * 32;
        mstoreCopy[2][2] = [
          { type: 'FunctionCallIdentifier', noSafeMath: true, name: 'add', value: 'add', text: 'add', toString: () => 'add' },
          [{ type: 'bracket', value: '(', text: '(', toString: () => '(' },
          clone(d[2][2]),
          { type: 'comma', text: ',', value: ',', toString: () => ',' },
          { type: 'NumberLiteral', value: valOffset, text: valOffset, toString: () => valOffset },
          { type: 'bracket', value: ')', text: ')', toString: () => ')' }],
        ];
        mstoreCopy[2][3][0] = v;

        return mstoreCopy;
      });

      d = d.concat(additionalMstores
          .map(v => [{ type: 'space', text: ' ', value: ' ', toString: () => ' ' }].concat(v)));
    }

    return d;
  }

  function extractArray(d) {
    return d;
  }

  function addValues(vals) {
    let cummulativeValue = utils.bigNumberify(0);
    let _vals = [0];

    for (let i = 0; i < vals.length; i++) {
      const v = vals[i];
      const isInt = Number.isInteger(v);

      if (v.type === 'HexLiteral'
        || v.type === 'NumberLiteral'
        || isInt) {
        if (isInt) {
          cummulativeValue = cummulativeValue.add(utils.bigNumberify(v));
        } else {
          cummulativeValue = cummulativeValue.add(v.value);
        }
      } else {
        _vals.push(v);
      }
    }

    // Vals
    _vals[0] = {
      type: 'HexLiteral',
      value: cummulativeValue.toHexString(),
      text: cummulativeValue.toHexString(),
      toString: () => cummulativeValue.toHexString(),
    };

    return _vals
      .map(v => `add(${v.value || v}, `)
      .concat(['0'])
      .concat(Array(_vals.length).fill(')'))
      .join('');
  }

  const gte = `
  function gte(x, y) -> result {
    if or(gt(x, y), eq(x, y)) {
      result := 0x01
    }
  }
  `;
  const lte = `
  function lte(x, y) -> result {
    if or(lt(x, y), eq(x, y)) {
      result := 0x01
    }
  }
  `;
  const neq = `
  function neq(x, y) -> result {
    if not(eq(x, y)) {
      result := 0x01
    }
  }
  `;
  const sliceMethod = `
function mslice(position, length) -> result {
  if gt(length, 32) { revert(0, 0) } // protect against overflow

  result := div(mload(position), exp(2, sub(256, mul(length, 8))))
}

`;
  const sliceObject = {
    value: sliceMethod,
    text: sliceMethod,
    type: 'MethodInjection',
    toString: () => sliceMethod,
  };

  const requireMethod = `
function require(arg) {
  if lt(arg, 1) {
    revert(0, 0)
  }
}
`;

  // Include safe maths
  let identifierTree = {};
%}

@lexer lexer

Yul -> (_ Chunk):* _ {% function(d) { return d; } %}
Chunk -> ObjectDefinition | CodeDefinition {% function(d) { return d; } %}
ObjectDefinition -> %objectKeyword _ %StringLiteral _ "{" ( _ objectStatement):* _ "}"
objectStatement -> CodeDefinition {% function(d) { return d[0]; } %}
  | DataDeclaration {% function(d) { return d[0]; } %}
  | ObjectDefinition {% function(d) { return d[0]; } %}
DataDeclaration -> %dataKeyword _ %StringLiteral _ (%StringLiteral | %HexLiteral)
CodeDefinition -> %codeKeyword _ Block {%
  function (d) {
    // Inject slice method
    const functionCalls = _filter(d, 'FunctionCallIdentifier');
    const usesSlice = functionCalls
      .filter(v => v.value === 'mslice' || v._includeMarker === 'mslice')
      .length > 0;
    let usesRequire = functionCalls
      .filter(v => v.usesRequire === true)
      .length > 0;
    const usesMath = functionCalls
      .filter(v => v.usesSafeMath === true)
      .length > 0;
    let __methodToInclude = {};

    // gte
    if (functionCalls
      .filter(v => v.usesGTE === true)
      .length > 0) {
      __methodToInclude['gte'] = gte;
    }

    // lte
    if (functionCalls
      .filter(v => v.usesLTE === true)
      .length > 0) {
      __methodToInclude['lte'] = lte;
    }

    // NEQ
    if (functionCalls
      .filter(v => v.usesNEQ === true)
      .length > 0) {
      __methodToInclude['neq'] = neq;
    }

    if (usesMath) {
      usesRequire = true;
      __methodToInclude['safeAdd'] = `
  function safeAdd(x, y) -> z {
    z := add(x, y)
    require(or(eq(z, x), gt(z, x)))
  }
  `;

      __methodToInclude['safeSub'] = `
  function safeSub(x, y) -> z {
    z := sub(x, y)
    require(or(eq(z, x), lt(z, x)))
  }
  `;

      __methodToInclude['safeMul'] = `
  function safeMul(x, y) -> z {
    if gt(y, 0) {
      z := mul(x, y)
      require(eq(div(z, y), x))
    }
  }
  `;

      __methodToInclude['safeDiv'] = `
    function safeDiv(x, y) -> z {
      require(gt(y, 0))
      z := div(x, y)
    }
    `;
    }

    if (usesRequire) {
      __methodToInclude['require'] = requireMethod;
    }

    if (usesSlice) {
      d[2].splice(2, 0, sliceObject);
    }

    d[2].splice(2, 0, Object.keys(__methodToInclude)
        .map(key => ({
      type: 'InjectedMethod',
      value: __methodToInclude[key],
      text: __methodToInclude[key],
      toString: () => __methodToInclude[key],
    })));


    return d;
  }
%}
Block -> "{" _ Statement (_ Statement):* _ "}" {% function(d, l) {
  const blockId = d[0].line + '.' + d[0].col;
  const currentBlock = identifierTree[blockId] = {
    type: 'Block',
    id: blockId,
    value: ``, // `/* ${blockId} */`,
  };

  // Scan for enums and constant declarations
  const enums = _filter(d, 'Enum')
    .reduce((acc, v) => Object.assign(acc, v.dataMap), {});
  const constants = _filter(d, 'Constant')
    .reduce((acc, v) => Object.assign(acc, v.dataMap), {});
  const mstructs = _filter(d, 'MemoryStructDeclaration')
    .reduce((acc, v) => Object.assign(acc, v.dataMap), {});
  const dtmstructs = _filter(d, 'DTypeMemoryStructDeclaration')
    .reduce((acc, v) => Object.assign(acc, v.dataMap), {});
  let methodToInclude = {};
  const duplicateChecks = {};
  let err = null;
  const dubcheck = (_type, v) => {
    if (typeof duplicateChecks[_type + v.name] === 'undefined') {
      duplicateChecks[_type + v.name] = v;
    } else {
      throw new Error(`${_type} already declared with the same identifier "${v.name}" on line ${duplicateChecks[_type + v.name].line} and ${v.line}. All ${_type} must have the unique names. Scoping coming soon.`);
    }
  };

  let _map = mapDeep(d, v => {
    if (err) { throw new Error(err) }

    // We have now set within this block context, this enum to Used
    if (v.type === 'Enum') {
      v.type = 'UsedEnum';
    }

    if (v.type === 'UsedEnum') {
      dubcheck('Enum', v);
    }

    // Set constants in context to used
    if (v.type === 'Constant') {
      v.type = 'UsedConstant';
      v.block = currentBlock.id;
    }

    if (v.type === 'UsedConstant') {
      for (let vi = 0; vi < v.__itendifiers.length; vi++) {
        // currentBlock.identifiers.push(v.__itendifiers[vi]);

        dubcheck('Constant', Object.assign(v, {
          name: v.__itendifiers[vi],
        }));
      }
    }

    // Used now..
    if (v.type === 'MemoryStructDeclaration') {
      v.type = 'UsedMemoryStructDeclaration';
    }

    if (v.type === 'UsedMemoryStructDeclaration') {
      dubcheck('MemoryStructDeclaration', v);
    }

    if (v.type === 'DTypeMemoryStructDeclaration') {
      v.type = 'UsedDTypeMemoryStructDeclaration';
    }

    if (v.type === 'UsedDTypeMemoryStructDeclaration') {
      dubcheck('DTypeMemoryStructDeclaration', v);
    }

    // Check for constant re-assignments
    if (v.type === 'Assignment') {
      for (var i = 0; i < v._identifiers.length; i++) {
        if (typeof constants[v._identifiers[i].value] !== 'undefined') {
          throw new Error(`Constant re-assignment '${v._identifiers[i].value}' to '${print(v._value)}' at line ${v.line}`);
        }
      }
    }

    // Replace enums
    if (v.type === 'Identifier'
      && typeof enums[v.value] !== "undefined") {

      // Replace out enums
      v.value = enums[v.value];
      v.text = enums[v.value];
    }

    if (v.type === 'FunctionCallIdentifier'
      && typeof mstructs[v.name] !== 'undefined') {
      methodToInclude[v.name] = "\n" + mstructs[v.name].method + "\n";

      // recursive get require
      const getRequired = required => {
        // include the required methods from the struct
        for (var im = 0; im < required.length; im++) {
          const requiredMethodName = required[im];

          // this has to be recursive for arrays etc..
          methodToInclude[requiredMethodName] = "\n"
            + mstructs[requiredMethodName].method
            + "\n";

          getRequired(mstructs[requiredMethodName].required);
        }
      };

      // get required..
      getRequired(mstructs[v.name].required);
    }

    if (v.type === 'FunctionCallIdentifier'
      && typeof dtmstructs[v.name] !== 'undefined') {
      methodToInclude[v.name] = "\n" + dtmstructs[v.name].method + "\n";

      // recursive get require
      const getRequired = required => {
        // include the required methods from the struct
        for (var im = 0; im < required.length; im++) {
          const requiredMethodName = required[im];

          // this has to be recursive for arrays etc..
          methodToInclude[requiredMethodName] = "\n"
            + dtmstructs[requiredMethodName].method
            + "\n";

          getRequired(dtmstructs[requiredMethodName].required);
        }
      };

      // get required..
      getRequired(dtmstructs[v.name].required);
    }

    if (v.type === 'FunctionCallIdentifier'
      && v.name === 'lte') {
      v.usesLTE = true;
    }

    if (v.type === 'FunctionCallIdentifier'
      && v.name === 'gte') {
      v.usesGTE = true;
    }

    if (v.type === 'FunctionCallIdentifier'
      && v.name === 'neq') {
      v.usesNEQ = true;
    }

    // Safe Math Multiply
    if (v.type === 'FunctionCallIdentifier'
      && v.name === 'require') {
      v.usesRequire = true;
    }

    if (v.type === 'FunctionCallIdentifier'
      && v.name === 'add'
      && !v.noSafeMath) {
      v.text = 'safeAdd';
      v.value = 'safeAdd';
      v.usesSafeMath = true;
    }

    if (v.type === 'FunctionCallIdentifier'
      && v.name === 'sub') {
      v.text = 'safeSub';
      v.value = 'safeSub';
      v.usesSafeMath = true;
    }

    if (v.type === 'FunctionCallIdentifier'
      && v.name === 'mul') {
      v.text = 'safeMul';
      v.value = 'safeMul';
      v.usesSafeMath = true;
    }

    if (v.type === 'FunctionCallIdentifier'
      && v.name === 'div') {
      v.text = 'safeDiv';
      v.value = 'safeDiv';
      v.usesSafeMath = true;
    }

    // Return object
    return v;
  });

  // inject mslice if any mstruct method used.
  if (Object.keys(methodToInclude).length > 0) {
    _map.splice(2, 0, {
      type: 'FunctionCallIdentifier',
      value: '',
      text: '',
      _includeMarker: 'mslice',
      toString: () => '',
    });
  }

  // set secondary kind of first element to Block
  _map.splice(0, 0, currentBlock);

  // add methods to include
  _map.splice(2, 0, Object.keys(methodToInclude)
      .map(key => ({
    type: 'InjectedMstructMethod',
    value: methodToInclude[key],
    text: methodToInclude[key],
    toString: () => methodToInclude[key],
  })));

  return _map;
} %}
  | "{" _ "}" {% extractArray %}
Switch -> "switch" _ Expression _ SwitchDefinitions
SwitchDefinitions -> SwitchDefinition (_ SwitchDefinition):* {%
  function(d) {
    const clean = d.filter(v => v);
    return d;
  }
%}
MAX_UINT -> %MAX_UINTLiteral {%
  function(d) {
    const val = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    return { type: 'HexNumber', value: val, text: val };
  }
%}
SigLiteral -> %SigLiteral {%
  function(d) {
    const sig = stringToSig(d[0].value.trim().slice(4).slice(0, -1)); // remove sig" and "
    return { type: 'HexNumber',
      isSignature: true,
      signature: d[0].value.trim(),
      value: sig,
      text: sig,
    };
  }
%}
DTSigLiteral -> %DTSigLiteral {%
  function(d) {
    const sig = dtypeutils.stringToSig(d[0].value);
    return { type: 'HexNumber',
      isSignature: true,
      signature: d[0].value.trim(),
      value: sig,
      text: sig,
    };
  }
%}
DTypeAbiLiteral -> %DTypeAbiLiteral {%
  function(d) {
    const abi = stringToSig(d[0].value.trim().slice(4).slice(0, -1)); // remove sig" and "
    return { type: 'HexNumber',
      isSignature: true,
      signature: d[0].value.trim(),
      value: abi,
      text: abi,
    };
  }
%}
TopicLiteral -> %TopicLiteral {%
  function(d) {
    const sig = stringToSig(d[0].value.trim().slice(6, -1));
    return {
      type: 'HexNumber',
      isTopic: true,
      topic: d[0].value.trim(),
      value: sig,
      text: sig,
    };
  }
%}
Boolean -> %boolean {% function(d) {
  if (d[0].value === "true") {
    return { type: 'HexNumber', value: '0x01', text: '0x01' };
  } else {
    return { type: 'HexNumber', value: '0x00', text: '0x00' };
  }
} %}
EnumDeclaration -> "enum" _ %Identifier _ "(" _ ")" {%
    function (d) {
      return {};
    }
  %}
  | "enum" _ %Identifier _ "(" _ IdentifierList _ ")" {%
  function (d) {
    const ids = _filter(d, 'Identifier');
    const name = ids[0].value;
    const markers = ids.slice(1);
    const dataMap = markers
      .reduce((acc, v, i) => Object.assign(acc, {
        [name + '.' + v]: i,
      }), {});

    return {
      type: 'Enum',
      value: '',
      text: '',
      ids,
      name,
      markers,
      line: ids[0].line,
      toString: () => '',
      dataMap,
    };
  }
%}
ForLoop -> "for" _ "{" (_ Statement):* _ "}" _ Expression _ "{" (_ Statement):* _ "}" _ Block
BreakContinue -> "break" | "continue"
SwitchDefinition -> Case | Default
Case -> "case" _ Literal _ Block
Default -> "default" _ Block
Statement -> FunctionDefinition
  | FunctionCall
  | ForLoop
  | VariableDeclaration
  | ConstantDeclaration
  | MemoryStructDeclaration
  | DTypeMemoryStructDeclaration
  | EnumDeclaration
  | IfStatement
  | Assignment
  | Switch
  | BreakContinue
IfStatement -> "if" _ Expression _ Block
NumericLiteral -> %NumberLiteral {% id %}
  | %HexNumber {% id %}
  | SigLiteral {% id %}
  | DTSigLiteral {% id %}
  | DTypeAbiLiteral {% id %}
  | TopicLiteral {% id %}
Literal -> %StringLiteral {% id %}
  | NumericLiteral {% id %}
  | MAX_UINT {% id %}
Expression -> Literal {% id %}
  | %Identifier {% id %}
  | FunctionCall {% id %}
  | Boolean {% id %}
ExpressionList -> "(" _ Expression ( _ "," _ Expression):* _ ")"
FunctionCall -> %Identifier _ ExpressionList {% functionCall %}
  | %Identifier _ "(" _ ")" {% functionCall %}
ArraySpecifier -> "[" _ NumericLiteral _ "]" {%
  function (d) {
    return {
      type: 'ArraySpecifier',
      value: d[2].value,
      text: d[2].value,
    };
  }
%}
IdentifierList -> %Identifier (_ "," _ %Identifier):* {% extractArray %}
MemoryStructIdentifier -> %Identifier _ ":" _ ( NumericLiteral | ArraySpecifier ) {%
  function (d) {
    // check memory struct nuermic literal or identifier
    const size = utils.bigNumberify(d[4][0].value);

    return {
      type: 'MemoryStructIdentifier',
      name: d[0].value,
      value: d[4][0],
    };
  }
%}
DTypeMemoryStructIdentifier -> %Identifier _ ":" _ %Identifier {%
  function (d) {
    // TODO anything to check?
    // TODO maybe here we get the dtype data and pass it down

    const value = d[4];
    value.dtype = dtypeutils.getById(value.value);
    value.dtype.length = dtypeutils.sizeBytes(value.dtype);

    return {
      type: 'DTypeMemoryStructIdentifier',
      name: d[0].value,
      value,
    };
  }
%}
MemoryStructList -> MemoryStructIdentifier (_ "," _ MemoryStructIdentifier):* {% extractArray %}
DTypeMemoryStructList -> DTypeMemoryStructIdentifier (_ "," _ DTypeMemoryStructIdentifier):* {% extractArray %}
MemoryStructDeclaration -> "mstruct" _ %Identifier _ "(" _ ")" {% function(d) {
    return {
      type: 'MemoryStructDeclaration',
      name: d[2].value,
      dataMap: {},
      value: '',
      text: '',
      line: d[2].line,
      toString: () => '',
    };
} %}
  | "mstruct" _ %Identifier _ "(" _ MemoryStructList _ ")" {%
  function (d) {
    const name = d[2].value;
    const properties = _filter(d[6], 'MemoryStructIdentifier');
    let methodList = properties.map(v => name + '.' + v.name);

    // check for array length specifiers
    for (var p = 0; p < properties.length; p++) {
      const prop = properties[p];

      if (prop.value.type === 'ArraySpecifier'
        && methodList.indexOf(name + '.' + prop.name + '.length') === -1) {
        throw new Error(`In memory struct "${name}", array property "${prop.name}" requires a ".length" property.`);
      }
    }

    let dataMap = properties.reduce((acc, v, i) => Object.assign(acc, {
      [name + '.' + v.name]: {
        size: v.value.type === 'ArraySpecifier'
          ? ('mul('
            + acc[name + '.' + v.name + '.length'].slice
            + ', ' + v.value.value + ')')
          : v.value,
        offset: addValues(methodList.slice(0, i)
          .map(name => acc[name].size)),
        slice: `mslice(${addValues(['pos'].concat(methodList.slice(0, i)
          .map(name => acc[name].size)))}, ${v.value.value})`,
        method: v.value.type === 'ArraySpecifier' ?
`
function ${name + '.' + v.name}(pos, i) -> res {
  res := mslice(add(${name + '.' + v.name}.position(pos),
    mul(i, ${v.value.value})), ${v.value.value})
}
`
: `
function ${name + '.' + v.name}(pos) -> res {
  res := mslice(${name + '.' + v.name}.position(pos), ${v.value.value})
}
`,
        required: [
          name + '.' + v.name + '.position',
        ],
      },
      [name + '.' + v.name + '.keccak256']: {
        method: `
function ${name + '.' + v.name + '.keccak256'}(pos) -> _hash {
  _hash := keccak256(${name + '.' + v.name + '.position'}(pos),
    ${v.value.type === 'ArraySpecifier'
      ? `mul(${name + '.' + v.name + '.length'}(pos),
          ${name + '.' + v.name + '.size'}())`
      : `${name + '.' + v.name + '.size'}()`})
}
`,
        required: [
          name + '.' + v.name + '.position',
          name + '.' + v.name + '.size',
        ].concat(v.value.type === 'ArraySpecifier'
          ? [name + '.' + v.name + '.length']
          : []),
      },
      [name + '.' + v.name + '.position']: {
        method: `
function ${name + '.' + v.name + '.position'}(pos) -> _offset {
  _offset := ${addValues(['pos'].concat(methodList.slice(0, i)
    .map(name => acc[name].size)))}
}
`,
        required: [],
      },
      [name + '.' + v.name + '.offset']: {
        method: `
function ${name + '.' + v.name + '.offset'}(pos) -> _offset {
${v.value.type === 'ArraySpecifier'
  ? `_offset := add(${name + '.' + v.name + '.position(pos)'}, mul(${name + '.' + v.name + '.length(pos)'}, ${v.value.value}))`
  : `_offset := add(${name + '.' + v.name + '.position(pos)'}, ${v.value.value})`}
}
`,
        required: (v.value.type === 'ArraySpecifier'
          ? [name + '.' + v.name + '.length', name + '.' + v.name + '.length.position']
          : []).concat([
            name + '.' + v.name + '.position',
          ]),
      },
      [name + '.' + v.name + '.index']: {
        method: `
function ${name + '.' + v.name + '.index'}() -> _index {
  _index := ${i}
}
`,
        required: [],
      },
      [name + '.' + v.name + '.size']: {
        method: `
function ${name + '.' + v.name + '.size'}() -> _size {
  _size := ${v.value.value}
}
`,
        required: [],
      },
    }), {});

    dataMap[name + '.keccak256'] = {
      method: `
function ${name + '.keccak256'}(pos) -> _hash {
  _hash := keccak256(pos, ${name + '.size'}(pos))
}
`,
      required: [name + '.size', name + '.offset'],
    };

    dataMap[name + '.size'] = {
      method: `
function ${name + '.size'}(pos) -> _offset {
  _offset := sub(${name + '.offset'}(pos), pos)
}
`,
      required: [name + '.offset'],
    };

    dataMap[name + '.offset'] = {
      method: `
function ${name + '.offset'}(pos) -> _offset {
  _offset := ${methodList.length
  ? methodList[methodList.length - 1] + '.offset(pos)' : '0'}
}
`,
      required: methodList.length > 0
        ? [methodList[methodList.length - 1] + '.offset']
            .concat(dataMap[methodList[methodList.length - 1] + '.offset'].required)
        : [],
    };

    return {
      type: 'MemoryStructDeclaration',
      name,
      dataMap,
      value: '',
      text: '',
      line: d[2].line,
      toString: () => '',
    };
  }
%}
DTypeMemoryStructDeclaration -> "dtmstruct" _ %Identifier _ "(" _ ")" {% function(d) {
    return {
      type: 'DTypeMemoryStructDeclaration',
      name: d[2].value,
      dataMap: {},
      value: '',
      text: '',
      line: d[2].line,
      toString: () => '',
    };
} %}
  | "dtmstruct" _ %Identifier _ "(" _ DTypeMemoryStructList _ ")" {%
  function (d) {
    const name = d[2].value;
    const properties = _filter(d[6], 'DTypeMemoryStructIdentifier');

    let methodList = properties.map(v => name + '.' + v.name);

    // check for array length specifiers
    for (var p = 0; p < properties.length; p++) {
      const prop = properties[p];

      if (prop.value.type === 'ArraySpecifier'
        && methodList.indexOf(name + '.' + prop.name + '.length') === -1) {
        throw new Error(`In memory struct "${name}", array property "${prop.name}" requires a ".length" property.`);
      }
    }

    let dataMap = properties.reduce((acc, v, i) => Object.assign(acc, {
      [name + '.' + v.name]: {
        size: v.value.type === 'ArraySpecifier'
          ? ('mul('
            + acc[name + '.' + v.name + '.length'].slice
            + ', ' + v.value.dtype.length + ')')
          : v.value.dtype.length,
        offset: addValues(methodList.slice(0, i)
          .map(name => acc[name].size)),
        slice: `mslice(${addValues(['pos'].concat(methodList.slice(0, i)
          .map(name => acc[name].size)))}, ${v.value.dtype.length})`,
        method: v.value.type === 'ArraySpecifier' ?
`
function ${name + '.' + v.name}(pos, i) -> res {
  res := mslice(add(${name + '.' + v.name}.position(pos),
    mul(i, ${v.value.dtype.length})), ${v.value.dtype.length})
}
`
: `
function ${name + '.' + v.name}(pos) -> res {
  res := mslice(${name + '.' + v.name}.position(pos), ${v.value.dtype.length})
}
`,
        required: [
          name + '.' + v.name + '.position',
        ],
      },
      [name + '.' + v.name + '.keccak256']: {
        method: `
function ${name + '.' + v.name + '.keccak256'}(pos) -> _hash {
  _hash := keccak256(${name + '.' + v.name + '.position'}(pos),
    ${v.value.type === 'ArraySpecifier'
      ? `mul(${name + '.' + v.name + '.length'}(pos),
          ${name + '.' + v.name + '.size'}())`
      : `${name + '.' + v.name + '.size'}()`})
}
`,
        required: [
          name + '.' + v.name + '.position',
          name + '.' + v.name + '.size',
        ].concat(v.value.type === 'ArraySpecifier'
          ? [name + '.' + v.name + '.length']
          : []),
      },
      [name + '.' + v.name + '.position']: {
        method: `
function ${name + '.' + v.name + '.position'}(pos) -> _offset {
  _offset := ${addValues(['pos'].concat(methodList.slice(0, i)
    .map(name => acc[name].size)))}
}
`,
        required: [],
      },
      [name + '.' + v.name + '.offset']: {
        method: `
function ${name + '.' + v.name + '.offset'}(pos) -> _offset {
${v.value.type === 'ArraySpecifier'
  ? `_offset := add(${name + '.' + v.name + '.position(pos)'}, mul(${name + '.' + v.name + '.length(pos)'}, ${v.value.dtype.length}))`
  : `_offset := add(${name + '.' + v.name + '.position(pos)'}, ${v.value.dtype.length})`}
}
`,
        required: (v.value.type === 'ArraySpecifier'
          ? [name + '.' + v.name + '.length', name + '.' + v.name + '.length.position']
          : []).concat([
            name + '.' + v.name + '.position',
          ]),
      },
      [name + '.' + v.name + '.index']: {
        method: `
function ${name + '.' + v.name + '.index'}() -> _index {
  _index := ${i}
}
`,
        required: [],
      },
      [name + '.' + v.name + '.size']: {
        method: `
function ${name + '.' + v.name + '.size'}() -> _size {
  _size := ${v.value.dtype.length}
}
`,
        required: [],
      },
    }), {});

    dataMap[name + '.keccak256'] = {
      method: `
function ${name + '.keccak256'}(pos) -> _hash {
  _hash := keccak256(pos, ${name + '.size'}(pos))
}
`,
      required: [name + '.size', name + '.offset'],
    };

    dataMap[name + '.size'] = {
      method: `
function ${name + '.size'}(pos) -> _offset {
  _offset := sub(${name + '.offset'}(pos), pos)
}
`,
      required: [name + '.offset'],
    };

    dataMap[name + '.offset'] = {
      method: `
function ${name + '.offset'}(pos) -> _offset {
  _offset := ${methodList.length
  ? methodList[methodList.length - 1] + '.offset(pos)' : '0'}
}
`,
      required: methodList.length > 0
        ? [methodList[methodList.length - 1] + '.offset']
            .concat(dataMap[methodList[methodList.length - 1] + '.offset'].required)
        : [],
    };
    return {
      type: 'DTypeMemoryStructDeclaration',
      name,
      dataMap,
      value: '',
      text: '',
      line: d[2].line,
      toString: () => '',
    };
  }
%}
VariableDeclaration -> "let" _ IdentifierList _ ":=" _ Expression
ConstantDeclaration -> %ConstIdentifier _ IdentifierList _ ":=" _ Expression {%
  function (d) {
    // Change const to let
    d[0].value = 'let ';
    d[0].text = 'let ';
    d[0].type = 'Constant';
    d[0].__itendifiers = _filter(d, 'Identifier', 'equate')
      .map(v => v.value);
    d[0].__value = d[6];
    d[0].dataMap = d[0].__itendifiers.reduce((acc, v) => Object.assign(acc, {
      [v]: d[0].__value,
    }), {});
    d.__constant = true;

    return d;
  }
%}
Assignment -> IdentifierList _ ":=" _ Expression {%
  function (d) {
    d[0][0]._identifiers = _filter(d[0], 'Identifier');
    d[0][0].type = 'Assignment';
    d[0][0]._value = d[4];
    return d;
  }
%}
FunctionDefinition -> "function" _ %Identifier _ "(" _ IdentifierList _ ")" _ "->" _ IdentifierList _ Block
  | "function" _ %Identifier _ "(" _ ")" _ "->" _ IdentifierList _ Block
  | "function" _ %Identifier _ "(" _ ")" _ "->" _ "(" _ ")" _ Block
  | "function" _ %Identifier _ "(" _ IdentifierList _ ")" _ Block
  | "function" _ %Identifier _ "(" _ ")" _ Block
Empty -> %space
  | %multiComment
  | %singleLineComment
_ -> (Empty):*
