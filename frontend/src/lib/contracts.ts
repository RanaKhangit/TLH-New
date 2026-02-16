export const CONTRACTS = {
  chainId: 11155111,
  network: "sepolia",
  admin: "0x3B50966A8B71f277e90e14cdC31455F6Af3977e6" as `0x${string}`,
  DIDRegistry: {
    proxy: "0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a" as `0x${string}`,
    implementation:
      "0xdeecd6a976d5999315dcf0cf8e7fa0e6ea887cd6" as `0x${string}`,
  },
  VCHashAnchors: {
    proxy: "0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68" as `0x${string}`,
    implementation:
      "0x3b7803ba081228ea98626be219755b0295267013" as `0x${string}`,
  },
  CredentialRegistry: {
    proxy: "0xae4b71776fab8e431cee4874ad3a2a97588d89fb" as `0x${string}`,
    implementation:
      "0x94de2311e67abd4332c358b9c3a37e231f298249" as `0x${string}`,
  },
  TrustAttestationVerifier: {
    proxy: "0x2ad7540b14585ebfb3c86604d1927b40e2efa5db" as `0x${string}`,
    implementation:
      "0x893aad8b32e77845b2485e033c7031e31c13ec9b" as `0x${string}`,
  },
  AttestationVerifier: {
    proxy: "0xce863e465f21df87ad9f0a2af838fac1750f08d2" as `0x${string}`,
    implementation:
      "0x2ae518d86774c814a73ca03464b355a3a228ac8d" as `0x${string}`,
  },
} as const;
