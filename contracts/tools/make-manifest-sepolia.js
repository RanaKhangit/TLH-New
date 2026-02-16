// tools/make-manifest-sepolia.js
const fs = require("fs");
const path = require("path");

const broadcastPath = path.join(__dirname, "..", "broadcast", "DeploySepolia.s.sol", "11155111", "run-latest.json");
const outPath = path.join(__dirname, "..", "deployment-manifest.sepolia.json");

// CHANGE THIS ONLY:
const ADMIN_ADDRESS = "0x3B50966A8B71f277e90e14cdC31455F6Af3977e6";

function isAddress(v) {
  return typeof v === "string" && /^0x[a-fA-F0-9]{40}$/.test(v);
}

function pickFirst(obj, keys) {
  for (const k of keys) if (obj && obj[k] != null) return obj[k];
  return null;
}

const raw = fs.readFileSync(broadcastPath, "utf8");
const data = JSON.parse(raw);

// Foundry broadcast shape differs slightly by version; we handle common fields.
const chainId = 11155111;
const deployer = pickFirst(data, ["deployer", "sender", "from"]) || null;
const txs = data.transactions || data.txs || [];

// Build an index of created contracts by name/address from transaction metadata.
const created = []; // {name, address, txHash, blockNumber}
for (const t of txs) {
  const txHash = t.hash || t.transactionHash || t.txHash || null;
  const blockNumber = t.blockNumber || t.receipt?.blockNumber || null;

  // Foundry usually includes `contractName` and `contractAddress` for creations
  const contractName = t.contractName || t.contract || t.artifactId || null;
  const contractAddress = t.contractAddress || t.address || t.receipt?.contractAddress || null;

  if (contractName && isAddress(contractAddress)) {
    created.push({ name: contractName, address: contractAddress, deployTx: txHash, blockNumber });
  }
}

// Heuristic: try to group into suite contracts you listed.
// You will STILL sanity-check the mapping after generation.
const suite = ["DIDRegistry", "VCHashAnchors", "CredentialRegistry", "TrustAttestationVerifier", "AttestationVerifier"];

function matchByName(target) {
  return created.filter(c => (c.name || "").includes(target));
}

const manifest = {
  chainId,
  network: "sepolia",
  deployer: deployer && isAddress(deployer) ? deployer : "0x3B50966A8B71f277e90e14cdC31455F6Af3977e6",
  admin: ADMIN_ADDRESS,
  gas: { totalEthApprox: "0.0447" },
  artifacts: {
    broadcastFile: "broadcast/DeploySepolia.s.sol/11155111/run-latest.json"
  },
  contracts: {}
};

for (const name of suite) {
  const matches = matchByName(name);

  // Often you'll have both Impl + Proxy. If contractName includes "Proxy", pick that separately.
  const proxy = matches.find(m => /proxy/i.test(m.name)) || null;
  const impl = matches.find(m => !/proxy/i.test(m.name)) || matches[0] || null;

  manifest.contracts[name] = {
    implementation: impl?.address || null,
    proxy: proxy?.address || null,
    deployTx: impl?.deployTx || proxy?.deployTx || null,
    blockNumber: impl?.blockNumber || proxy?.blockNumber || null
  };
}

fs.writeFileSync(outPath, JSON.stringify(manifest, null, 2));
console.log("Wrote:", outPath);
console.log("IMPORTANT: sanity-check each contract mapping vs run-latest.json output.");
