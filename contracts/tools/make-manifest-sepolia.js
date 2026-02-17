// tools/make-manifest-sepolia.js
const fs = require("fs");
const path = require("path");

const broadcastPath = path.join(
  __dirname,
  "..",
  "broadcast",
  "DeploySepolia.s.sol",
  "11155111",
  "run-latest.json"
);
const outPath = path.join(__dirname, "..", "deployment-manifest.sepolia.json");
const ADMIN_ADDRESS =
  process.env.ADMIN_ADDRESS || "0x3B50966A8B71f277e90e14cdC31455F6Af3977e6";

const SUITE = [
  "DIDRegistry",
  "VCHashAnchors",
  "CredentialRegistry",
  "TrustAttestationVerifier",
  "AttestationVerifier",
];

function isAddress(v) {
  return typeof v === "string" && /^0x[a-fA-F0-9]{40}$/.test(v);
}

function toLowerAddress(v) {
  return isAddress(v) ? v.toLowerCase() : null;
}

function toDec(value) {
  if (value == null) return null;
  if (typeof value === "number") return value;
  if (typeof value === "string" && value.startsWith("0x")) {
    return parseInt(value, 16);
  }
  const n = Number(value);
  return Number.isNaN(n) ? null : n;
}

function mustAddress(v, label) {
  if (!isAddress(v)) throw new Error(`Invalid address for ${label}: ${v}`);
  return v.toLowerCase();
}

const raw = fs.readFileSync(broadcastPath, "utf8");
const data = JSON.parse(raw);
const txs = data.transactions || [];
const receipts = data.receipts || [];
const receiptByTxHash = new Map(
  receipts.map((r) => [(r.transactionHash || "").toLowerCase(), r])
);

const creates = txs
  .filter((t) => t.transactionType === "CREATE" && isAddress(t.contractAddress))
  .map((t) => {
    const txHash = (t.hash || "").toLowerCase();
    const receipt = receiptByTxHash.get(txHash);
    return {
      hash: txHash,
      contractName: t.contractName || "",
      contractAddress: t.contractAddress.toLowerCase(),
      args: Array.isArray(t.arguments) ? t.arguments : [],
      from: t.transaction?.from || null,
      blockNumber: toDec(receipt?.blockNumber ?? t.blockNumber ?? t.receipt?.blockNumber),
    };
  });

function findImplementation(name) {
  return creates.find((c) => c.contractName === name);
}

function findProxyForImplementation(implementationAddress) {
  const target = toLowerAddress(implementationAddress);
  return creates.find(
    (c) =>
      c.contractName === "ERC1967Proxy" &&
      c.args.length > 0 &&
      toLowerAddress(c.args[0]) === target
  );
}

const deployer =
  creates.find((c) => c.from)?.from?.toLowerCase() ||
  "0x3B50966A8B71f277e90e14cdC31455F6Af3977e6".toLowerCase();

const manifest = {
  chainId: 11155111,
  network: "sepolia",
  deployer,
  admin: mustAddress(ADMIN_ADDRESS, "ADMIN_ADDRESS"),
  gas: { totalEthApprox: "0.0447" },
  artifacts: {
    broadcastFile: "broadcast/DeploySepolia.s.sol/11155111/run-latest.json",
  },
  contracts: {},
};

for (const name of SUITE) {
  const impl = findImplementation(name);
  if (!impl) throw new Error(`Missing implementation CREATE tx for ${name}`);

  const proxy = findProxyForImplementation(impl.contractAddress);
  if (!proxy) throw new Error(`Missing proxy CREATE tx for ${name}`);

  manifest.contracts[name] = {
    implementation: impl.contractAddress,
    proxy: proxy.contractAddress,
    implDeployTx: impl.hash,
    proxyDeployTx: proxy.hash,
    blockNumber: proxy.blockNumber ?? impl.blockNumber ?? null,
  };
}

fs.writeFileSync(outPath, JSON.stringify(manifest, null, 2));
console.log("Wrote:", outPath);
