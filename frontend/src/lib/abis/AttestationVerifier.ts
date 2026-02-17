export const AttestationVerifierABI = [
  {
    type: "function",
    name: "verifyAttestation",
    inputs: [{ name: "attestationId", type: "bytes32" }],
    outputs: [
      { name: "exists", type: "bool" },
      { name: "subjectDID", type: "bytes32" },
      { name: "predicateHash", type: "bytes32" },
      { name: "result", type: "bool" },
      { name: "timestamp", type: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "didRegistry",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "vcHashAnchors",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
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
    name: "SIGNER_ADMIN_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "submitAttestation",
    inputs: [
      { name: "attestationId", type: "bytes32" },
      { name: "subjectDID", type: "bytes32" },
      { name: "predicateData", type: "bytes" },
      { name: "signature", type: "bytes" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;
