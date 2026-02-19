import { NextRequest, NextResponse } from "next/server";

const EA_API = process.env.EA_URL || "http://localhost:8788";

// --- Rate limiting ---
const rateLimitMap = new Map<string, number[]>();
const RATE_LIMIT_WINDOW = 60_000;
const RATE_LIMIT_MAX = 5;

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const timestamps = (rateLimitMap.get(ip) || []).filter(t => now - t < RATE_LIMIT_WINDOW);
  if (timestamps.length >= RATE_LIMIT_MAX) return true;
  timestamps.push(now);
  rateLimitMap.set(ip, timestamps);
  return false;
}

const SAFE_STRING = /^[a-zA-Z0-9\s\-_:.]{1,200}$/;

export async function POST(req: NextRequest) {
  const ip = req.headers.get("x-forwarded-for") || "unknown";
  if (isRateLimited(ip)) {
    return NextResponse.json({ error: "Too many requests" }, { status: 429 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid JSON in request body" },
      { status: 400 }
    );
  }

  const { clinicianDID, surname, givenName } = body as {
    clinicianDID?: string;
    surname?: string;
    givenName?: string;
  };

  // Input validation
  if (clinicianDID && !SAFE_STRING.test(clinicianDID)) {
    return NextResponse.json({ error: "Invalid clinicianDID format" }, { status: 400 });
  }
  if (surname && !SAFE_STRING.test(surname)) {
    return NextResponse.json({ error: "Invalid surname format" }, { status: 400 });
  }
  if (givenName && !SAFE_STRING.test(givenName)) {
    return NextResponse.json({ error: "Invalid givenName format" }, { status: 400 });
  }

  const eaPayload = {
    id: `pipeline-${Date.now()}`,
    data: {
      clinicianDID: clinicianDID || `did:tlh:${(givenName || "unknown").toLowerCase()}-${(surname || "unknown").toLowerCase()}`,
      surname,
      givenName,
    },
  };

  let eaRes: Response;
  try {
    eaRes = await fetch(EA_API, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(eaPayload),
      signal: AbortSignal.timeout(60000),
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    return NextResponse.json(
      { error: `EA unreachable: ${msg}` },
      { status: 502 }
    );
  }

  if (!eaRes.ok) {
    return NextResponse.json(
      { error: "Pipeline request failed" },
      { status: eaRes.status }
    );
  }

  const data = await eaRes.json();
  return NextResponse.json(data);
}
