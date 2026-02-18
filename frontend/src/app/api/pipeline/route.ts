import { NextRequest, NextResponse } from "next/server";

const EA_API = process.env.EA_URL || process.env.NEXT_PUBLIC_EA_URL || "http://localhost:8788";

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { clinicianDID, surname, givenName } = body;

  const eaPayload = {
    id: `pipeline-${Date.now()}`,
    data: {
      clinicianDID: clinicianDID || `did:tlh:${(givenName || "unknown").toLowerCase()}-${(surname || "unknown").toLowerCase()}`,
      surname,
      givenName,
    },
  };

  const eaRes = await fetch(EA_API, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(eaPayload),
  });

  if (!eaRes.ok) {
    const text = await eaRes.text();
    return NextResponse.json(
      { error: `EA returned ${eaRes.status}`, details: text },
      { status: eaRes.status }
    );
  }

  const data = await eaRes.json();
  return NextResponse.json(data);
}
