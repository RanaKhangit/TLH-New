const fs = require("fs");

const path = "broadcast/DeploySepolia.s.sol/11155111/run-latest.json";
const raw = fs.readFileSync(path, "utf8");
const j = JSON.parse(raw);

const txs = j.transactions || j.txs || [];

const rows = [];

for (const t of txs) {
  const name =
    t.contractName ||
    t.contract ||
    t.artifactId ||
    "";

  const address =
    t.contractAddress ||
    t.address ||
    (t.receipt && t.receipt.contractAddress) ||
    "";

  const hash =
    t.hash ||
    t.transactionHash ||
    t.txHash ||
    "";

  if (name && address) {
    rows.push({ name, address, hash });
  }
}

console.log("\nALL CREATED CONTRACTS:\n");
for (const r of rows) {
  console.log(r.name + " | " + r.address + " | " + r.hash);
}

console.log("\nPROXY-LIKE CONTRACTS:\n");
for (const r of rows) {
  if (/proxy|1967/i.test(r.name)) {
    console.log(r.name + " | " + r.address + " | " + r.hash);
  }
}
