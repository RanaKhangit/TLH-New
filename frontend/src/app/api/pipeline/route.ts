import { NextRequest, NextResponse } from "next/server";

const EA_API = process.env.EA_URL || process.env.NEXT_PUBLIC_EA_URL || "http://localhost:8788";

export async function POST(req: NextRequest) {
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
    const text = await eaRes.text().catch(() => "");
    return NextResponse.json(
      { error: `EA returned ${eaRes.status}`, details: text },
      { status: eaRes.status }
    );
  }

  const data = await eaRes.json();
  return NextResponse.json(data);
}
