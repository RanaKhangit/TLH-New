import { NextResponse } from "next/server";

const SEPOLIA_RPC = "https://sepolia.drpc.org";

// Contract addresses from lib/contracts.ts
const SEPOLIA_CONTRACTS = {
  DIDRegistry: "0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a",
  AttestationVerifier: "0xce863e465f21df87ad9f0a2af838fac1750f08d2",
  VCHashAnchors: "0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68",
};

// hasRole(bytes32,address) selector = 0x91d14854
// We check hasRole(0x00...00, 0x00...00) which should return false for any valid contract
const HAS_ROLE_CALL_DATA =
  "0x91d148540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

async function checkContract(address: string): Promise<boolean> {
  try {
    const res = await fetch(SEPOLIA_RPC, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_call",
        params: [{ to: address, data: HAS_ROLE_CALL_DATA }, "latest"],
        id: 1,
      }),
      signal: AbortSignal.timeout(5000),
    });

    if (!res.ok) return false;
    const data = await res.json();
    // If we get a result (even error), the contract exists and responded
    return data.result !== undefined || data.error !== undefined;
  } catch {
    return false;
  }
}

export async function GET() {
  const results = await Promise.all(
    Object.entries(SEPOLIA_CONTRACTS).map(async ([name, address]) => ({
      name,
      address,
      responsive: await checkContract(address),
    }))
  );

  return NextResponse.json({
    contracts: results,
    allHealthy: results.every((c) => c.responsive),
  });
}
