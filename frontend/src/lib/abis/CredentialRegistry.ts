export const CredentialRegistryABI = [
  {
    type: "function",
    name: "getCredential",
    inputs: [
      { name: "subjectDID", type: "bytes32" },
      { name: "predicateType", type: "bytes32" },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "subjectDID", type: "bytes32" },
          { name: "predicateType", type: "bytes32" },
          { name: "valid", type: "bool" },
          { name: "checkedAt", type: "uint256" },
          { name: "expiresAt", type: "uint256" },
          { name: "attestationId", type: "bytes32" },
          { name: "status", type: "uint8" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isCredentialValid",
    inputs: [
      { name: "subjectDID", type: "bytes32" },
      { name: "predicateType", type: "bytes32" },
    ],
    outputs: [{ name: "", type: "bool" }],
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
    name: "VERIFIER_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
] as const;
