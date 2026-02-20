import { NextResponse } from "next/server";

const SEPOLIA_RPCS = [
  "https://sepolia.drpc.org",
  "https://ethereum-sepolia-rpc.publicnode.com",
  "https://rpc2.sepolia.org",
];

export async function GET() {
  const start = performance.now();

  for (const rpc of SEPOLIA_RPCS) {
    try {
      const res = await fetch(rpc, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          jsonrpc: "2.0",
          method: "eth_blockNumber",
          params: [],
          id: 1,
        }),
        signal: AbortSignal.timeout(5000),
      });

      if (!res.ok) continue;

      const data = await res.json();
      if (data.result) {
        const blockNumber = parseInt(data.result, 16);
        return NextResponse.json({
          ok: true,
          blockNumber,
          latencyMs: Math.round(performance.now() - start),
          rpc,
        });
      }
    } catch {
      continue;
    }
  }

  return NextResponse.json({
    ok: false,
    blockNumber: null,
    latencyMs: null,
    rpc: null,
  });
}
