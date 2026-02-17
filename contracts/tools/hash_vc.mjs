import fs from "fs";
import crypto from "crypto";

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

const path = process.argv[2];
if (!path) throw new Error("Usage: node hash_vc.mjs <vc.json>");

const vc = JSON.parse(fs.readFileSync(path, "utf8"));
const canon = JSON.stringify(canonical(vc)); // deterministic ordering
const hash = "0x" + crypto.createHash("sha256").update(canon, "utf8").digest("hex"); // 32 bytes

console.log(hash);
