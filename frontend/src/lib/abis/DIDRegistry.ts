export const DIDRegistryABI = [
  {
    type: "function",
    name: "resolveDID",
    inputs: [{ name: "did", type: "bytes32" }],
    outputs: [
      { name: "controller", type: "address" },
      { name: "active", type: "bool" },
      { name: "registeredAt", type: "uint256" },
      { name: "updatedAt", type: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "lastUpdatedAt",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "hasRole",
    inputs: [
      { name: "role", type: "bytes32" },
      { name: "account", type: "address" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "REGISTRAR_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "DEFAULT_ADMIN_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "registerDID",
    inputs: [
      { name: "did", type: "bytes32" },
      { name: "controller", type: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;
