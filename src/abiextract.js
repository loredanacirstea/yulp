// Only takes into consideration signatures containing modifiers or return def
// group0 full expression
// group1 'function' - optional
// group2 function name
// group3 arguments
// group4 modifiers & return
const funcRegex = /case sig"(function )?(.*)\((.*)\)\s(.*)?"/gi;
const funcRegex2 = /sig"(function )?(.*)\((.*)\)\s(.*)?"/;
const funcRegexFallb = /sig"(function )?(.*)\((.*)\)"/

const mutabilityRegex = /pure|view|payable/;
const outputRegex = /\((.*)\)/;

// Find event definitions
// group0 full expression
// group1 'event'
// group2 name
// group3 inputs e.g. address indexed _owner, address indexed _spender
const eventRegex = /topic"(event )?(.*)\((.*)\)"/gi;
const eventRegex2 = /topic"(event )?(.*)\((.*)\)"/;

export const getMatches = (source, regexp) => {
  let match;
  const imports = [];

  while ((match = regexp.exec(source)) !== null) {
    imports.push(match);
  }
  return imports;
}

// address _from, address _to, uint _value
// address indexed _owner, address indexed _spender, uint256 _value
const ioAbiFromStr = ioStr => {
  if (!ioStr) return [];
  return ioStr.split(',')
    .map(pair => pair.trim().split(' '))
    .map(input => {
      const io = {type: input[0]};
      if (input[1] === 'indexed') {
        io.indexed = true;
        io.name = input[2] || '';
      } else {
        io.name = input[1] || '';
      }
      return io;
    });
}

const stateFromModifiers = stateModifier => {
  if (!stateModifier) return 'nonpayable';
  return stateModifier;
}

const funcAbiFromMatch = (name, inputStr, stateModifier, outputStr) => {
  return {
    name,
    type: 'function',
    stateMutability: stateFromModifiers(stateModifier),
    inputs: ioAbiFromStr(inputStr),
    outputs: ioAbiFromStr(outputStr),
  }
}

const eventAbiFromMatch = (name, inputStr) => {
  return {
    name,
    type: 'event',
    inputs: ioAbiFromStr(inputStr),
    // anonymous
  }
}

const abiBuildMatches = (funcMatches, eventMatches) => {
  if (!(funcMatches instanceof Array)) return [];

  const funcabi = funcMatches.map(match => {
    const [, , name, inputs, tail] = match;
    let stateModifier = null;
    let outputs = null;

    if (tail) {
      stateModifier = tail.match(mutabilityRegex);
      stateModifier = stateModifier ? stateModifier[0] : null;
      outputs = tail.match(outputRegex);
      outputs = outputs ? outputs[1] : null;
    }

    return funcAbiFromMatch(name, inputs, stateModifier, outputs);
  });

  const evabi = eventMatches.map(match => {
    const [, , name, inputs] = match;
    return eventAbiFromMatch(name, inputs);
  });

  return funcabi.concat(evabi);
}

// TODO: struct definition in signature - components
export const abiBuildSigsTopics = (signatures=[], topics=[]) => {
  const funcMatches = signatures.map(sig => {
    let match = sig.match(funcRegex2);
    if (!match) match = sig.match(funcRegexFallb);
    return match;
  });
  console.log('funcMatches', funcMatches);
  const topicMatches = topics.map(topic => topic.match(eventRegex2));

  return abiBuildMatches(funcMatches, topicMatches);
}

export const abiToStr = abi => {
  return `${abi.name}(${abi.inputs.map(inp => inp.type).join(',')})`;
}
