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

- type: array
  type_choice: 4
  inputs:
    - type: u32
      label: u32_[*]
  outputs: []
  optionals: []

- type: array
  size: 2
  type_choice: 4
  inputs:
    - type: u32
      label: u32_[*]
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

- type: address
  type_choice: 2
  inputs:
    - type: byte20
      label: address
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

- type: Balances
  type_choice: 4
  inputs:
    - type: Balance
      label: balance_[*]
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
`

export { dtypedefs };
