/** Sepolia shared anchor contracts (DID + VCHash + AttestationVerifier) */
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
  AttestationVerifier: {
    proxy: "0xce863e465f21df87ad9f0a2af838fac1750f08d2" as `0x${string}`,
    implementation:
      "0x2ae518d86774c814a73ca03464b355a3a228ac8d" as `0x${string}`,
  },
} as const;

/** CCIP cross-chain contracts on Sepolia */
export const CCIP_CONTRACTS = {
  TLHCCIPReceiver: {
    proxy: "0x234Aec51d3977bA5174B068d2Daf15e5367C0bF0" as `0x${string}`,
    implementation:
      "0x873A6c71eB179da1e6a53E4958435919CCb0940F" as `0x${string}`,
  },
  TLHCCIPSender: {
    proxy: "0xB8238cA59c7479e16d888A86A533A3113886A260" as `0x${string}`,
    implementation:
      "0x30De5aDcD1Db72F93Ed4ceF92240b2A97D652969" as `0x${string}`,
  },
} as const;

/** Chainlink Automation jobs (node-centric) */
export const CHAINLINK_JOBS = [
  {
    name: "DECO Verification (Webhook)",
    type: "webhook",
    file: "deco-verification-job.toml",
    description: "On-demand DECO attestation verification",
  },
  {
    name: "DECO Verification (Cron)",
    type: "cron",
    schedule: "0 * * * * *",
    file: "deco-verification-cron.toml",
    description: "Scheduled credential re-verification",
  },
] as const;

/** Private trust chain contracts (Polygon Edge, chain ID 100100) */
export const PRIVATE_CHAIN_CONTRACTS = {
  chainId: 100100,
  network: "TLH Private Chain",
  admin: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" as `0x${string}`,
  CredentialRegistry: {
    proxy: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9" as `0x${string}`,
  },
  TrustAttestationVerifier: {
    proxy: "0x0165878A594ca255338adfa4d48449f69242Eb8F" as `0x${string}`,
  },
} as const;
