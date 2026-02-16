export const VCHashAnchorsABI = [
  {
    type: "function",
    name: "getAnchor",
    inputs: [
      { name: "subjectDID", type: "bytes32" },
      { name: "vcType", type: "bytes32" },
    ],
    outputs: [
      { name: "contentHash", type: "bytes32" },
      { name: "anchoredAt", type: "uint256" },
      { name: "revoked", type: "bool" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAnchorHistory",
    inputs: [
      { name: "subjectDID", type: "bytes32" },
      { name: "vcType", type: "bytes32" },
    ],
    outputs: [{ name: "", type: "bytes32[]" }],
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
    name: "ANCHOR_WRITER_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
] as const;
