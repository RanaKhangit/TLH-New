import fs from "fs";
import crypto from "crypto";
import { spawnSync } from "child_process";

// ---- Canonicalization (deterministic key ordering) ----
function canonical(obj) {
  if (Array.isArray(obj)) return obj.map(canonical);
  if (obj && typeof obj === "object") {
    return Object.keys(obj).sort().reduce((acc, k) => {
      acc[k] = canonical(obj[k]);
      return acc;
    }, {});
  }
  return obj;
}

function sha256Hex(str) {
  return "0x" + crypto.createHash("sha256").update(str, "utf8").digest("hex");
}

async function keccakViaCast(input) {
  const res = spawnSync("cast", ["keccak", input], { encoding: "utf8" });
  if (res.status !== 0) throw new Error(`cast keccak failed: ${res.stderr || res.stdout}`);
  return res.stdout.trim();
}

function usage() {
  console.log("Usage:");
  console.log("  node tools/verify_vc_anchored.mjs <vc.json> <VC_TYPE_STR> <VCA_PROXY> <RPC_URL> <FROM_ADDRESS>");
  process.exit(1);
}

if (process.argv.length < 7) usage();

const vcPath    = process.argv[2];
const vcTypeStr = process.argv[3];
const vcaProxy  = process.argv[4];
const rpcUrl    = process.argv[5];
const fromAddr  = process.argv[6];

if (!fs.existsSync(vcPath)) throw new Error(`VC file not found: ${vcPath}`);

const vcRaw = fs.readFileSync(vcPath, "utf8");
const vc = JSON.parse(vcRaw);

const subjectDid = vc?.credentialSubject?.id;
if (!subjectDid || typeof subjectDid !== "string") {
  throw new Error("VC JSON missing credentialSubject.id (string).");
}

const canon = JSON.stringify(canonical(vc));
const contentHash = sha256Hex(canon);

const subjectDID32 = await keccakViaCast(subjectDid);
const vcType32     = await keccakViaCast(vcTypeStr);

const call = spawnSync(
  "cast",
  [
    "call",
    vcaProxy,
    "getAnchor(bytes32,bytes32)(bytes32,uint256,bool)",
    subjectDID32,
    vcType32,
    "--rpc-url",
    rpcUrl,
    "--from",
    fromAddr
  ],
  { encoding: "utf8" }
);

if (call.status !== 0) {
  console.log("VERIFY: FAIL");
  console.log("Reason: getAnchor reverted or call failed.");
  console.log((call.stderr || call.stdout).trim());
  console.log("");
  console.log("Computed inputs:");
  console.log(`  subjectDid      = ${subjectDid}`);
  console.log(`  subjectDID32    = ${subjectDID32}`);
  console.log(`  vcTypeStr       = ${vcTypeStr}`);
  console.log(`  vcType32        = ${vcType32}`);
  console.log(`  contentHash     = ${contentHash}`);
  process.exit(2);
}

const out = call.stdout.trim().split(/\r?\n/);
const onchainContentHash = out[0]?.trim();
const anchoredAtStr      = out[1]?.trim()?.split(" ")[0];
const revokedStr         = out[2]?.trim();

const anchoredAt = anchoredAtStr ? BigInt(anchoredAtStr) : 0n;
const revoked = (revokedStr === "true");
const hashMatches = (onchainContentHash?.toLowerCase() === contentHash.toLowerCase());

console.log("VERIFY: " + (hashMatches ? "PASS" : "FAIL"));
console.log("");
console.log("Computed:");
console.log(`  subjectDid      = ${subjectDid}`);
console.log(`  subjectDID32    = ${subjectDID32}`);
console.log(`  vcTypeStr       = ${vcTypeStr}`);
console.log(`  vcType32        = ${vcType32}`);
console.log(`  contentHash     = ${contentHash}`);
console.log("");
console.log("On-chain (getAnchor):");
console.log(`  contentHash     = ${onchainContentHash}`);
console.log(`  anchoredAt      = ${anchoredAt.toString()}`);
console.log(`  revoked         = ${revoked}`);
console.log("");

if (!hashMatches) {
  console.log("Mismatch: on-chain contentHash does not match computed hash of vc.json.");
  process.exit(3);
}

process.exit(0);
