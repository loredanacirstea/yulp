const dtypedefs = `
- type: bit
  type_choice: 0
  size: 1
  inputs: []
  outputs: []
  optionals: []

- type: bit
  size: 8
  type_choice: 1
  inputs:
    - type: bit1
      label: bit1_[x]
  outputs: []
  optionals: []

- type: bit
  size: 32
  type_choice: 1
  inputs:
    - type: bit1
      label: bit1_[x]
  outputs: []
  optionals: []

- type: byte
  size: 1
  type_choice: 1
  inputs:
    - type: bit8
      label: bit8_[x]
  outputs: []
  optionals: []

- type: byte
  size: 4
  type_choice: 1
  inputs:
    - type: byte1
      label: bit1_[x]
  outputs: []
  optionals: []

- type: bool
  type_choice: 2
  inputs:
    - type: byte1
      label: byte1
  outputs: []
  optionals: []

- type: u
  type_choice: 1
  size: 8
  inputs:
    - type: bit1
      label: bit1_1
  outputs: []
  optionals: []

- type: u
  type_choice: 1
  size: 32
  inputs:
    - type: bit1
      label: bit1_1
  outputs: []
  optionals: []

- type: u
  type_choice: 1
  size: 256
  inputs:
    - type: bit1
      label: bit1_1
  outputs: []
  optionals: []

- type: EthereumFunctionSignature
  type_choice: 2
  inputs:
    - type: byte4
      label: sig
  outputs: []
  optionals: []

- type: dTypeSignature
  type_choice: 2
  inputs:
    - type: byte4
      label: sig
  outputs: []
  optionals: []

- type: array
  type_choice: 4
  inputs:
    - type: u32
      label: u32item
  outputs: []
  optionals: []

- type: array
  size: 2
  type_choice: 4
  inputs:
    - type: u32
      label: u32item
  outputs: []
  optionals: []

- type: byte
  size: 20
  type_choice: 1
  inputs:
    - type: byte1
      label: bit1_[x]
  outputs: []
  optionals: []

- type: array
  type_choice: 4
  inputs:
    - type: byte
      label: byteitem
  outputs: []
  optionals: []

- type: array
  type_choice: 4
  inputs:
    - type: u8
      label: u8item
  outputs: []
  optionals: []

- type: array
  type_choice: 4
  inputs:
    - type: bool
      label: boolitem
  outputs: []
  optionals: []

- type: address
  type_choice: 2
  inputs:
    - type: byte20
      label: address
  outputs: []
  optionals: []

- type: char
  type_choice: 2
  inputs:
    - type: byte1
      label: char
  outputs: []
  optionals: []

- type: array
  type_choice: 4
  inputs:
    - type: char
      label: charitem
  outputs: []
  optionals: []

- type: Balance
  type_choice: 3
  inputs:
    - type: address
      label: token
    - type: u32
      label: value
  outputs: []
  optionals: []

- type: array
  type_choice: 4
  inputs:
    - type: Balance
      label: balanceitem
  outputs: []
  optionals: []

- type: Rectangle
  type_choice: 3
  inputs:
    - type: u32array2
      label: dimensions
    - type: u32
      label: value
  outputs: []
  optionals: []

- type: ProgStep
  type_choice: 3
  inputs:
    - type: byte4
      label: typeid
    - type: u8array
      label: inputIndexes
    - type: boolarray
      label: outputHasSlotSize
  outputs: []
  optionals: []

- type: array
  type_choice: 4
  inputs:
    - type: ProgStep
      label: stepitem
  outputs: []
  optionals: []

- type: Type
  type_choice: 3
  inputs:
    - type: dTypeSignature
      label: sig_bytecode
    - type: dTypeSignature
      label: sig_in
    - type: dTypeSignature
      label: sig_out
    - type: u32
      label: ssize
    - type: ProgSteparray
      label: steps
  outputs: []
  optionals: []
`

export { dtypedefs };
