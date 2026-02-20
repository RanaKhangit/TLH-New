import { NextResponse } from "next/server";

const PRIVATE_CHAIN_RPC = process.env.NEXT_PUBLIC_PRIVATE_CHAIN_RPC_URL || "http://localhost:8545";

export async function GET() {
  const start = performance.now();

  try {
    const res = await fetch(PRIVATE_CHAIN_RPC, {
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

    if (!res.ok) {
      return NextResponse.json({ ok: false, blockNumber: null, latencyMs: null });
    }

    const data = await res.json();
    if (data.result) {
      const blockNumber = parseInt(data.result, 16);
      return NextResponse.json({
        ok: true,
        blockNumber,
        latencyMs: Math.round(performance.now() - start),
      });
    }

    return NextResponse.json({ ok: false, blockNumber: null, latencyMs: null });
  } catch {
    return NextResponse.json({ ok: false, blockNumber: null, latencyMs: null });
  }
}
