const PROVER_API =
  process.env.NEXT_PUBLIC_PROVER_API_URL || "http://localhost:8787";
const EA_API = process.env.NEXT_PUBLIC_EA_URL || "http://localhost:8788";

export interface DecoVerifyResult {
  result: "PASS" | "FAIL";
  proofId: string;
  verificationType: string;
  completedAt: string;
}

export interface DecoAttestation {
  signature_scheme: string;
  attestation_scheme: string;
  data_hex: string;
  signature_hex: string;
  public_key_hex: string;
}

export interface GMCRecord {
  gmcRefNo: string;
  surname: string;
  givenName: string;
  gender: string;
  qualification: string;
  qualYear: string;
  qualPlace: string;
  registrationStatus: string;
  revalidationStatus: string;
}

export interface PipelineResult {
  jobRunID: string;
  statusCode: number;
  data: {
    result: string;
    txHash: string;
    proofId: string;
    attestationId: string;
    verificationResult: string;
  };
}

async function fetchJSON<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, init);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json() as Promise<T>;
}

export async function fetchDecoVerify(): Promise<DecoVerifyResult> {
  return fetchJSON<DecoVerifyResult>(`${PROVER_API}/deco/verify`);
}

export async function fetchDecoAttestation(): Promise<DecoAttestation> {
  return fetchJSON<DecoAttestation>(`${PROVER_API}/deco/attestation`);
}

export async function fetchGMCLookup(
  surname: string,
  givenName: string
): Promise<GMCRecord[]> {
  const params = new URLSearchParams({ surname, givenName });
  const data = await fetchJSON<GMCRecord | GMCRecord[]>(
    `${PROVER_API}/gmc/lookup?${params}`
  );
  return Array.isArray(data) ? data : [data];
}

export async function fetchProverHealth(): Promise<boolean> {
  try {
    await fetch(`${PROVER_API}/health`, { signal: AbortSignal.timeout(3000) });
    return true;
  } catch {
    return false;
  }
}

export async function fetchEAHealth(): Promise<boolean> {
  try {
    await fetch(`${EA_API}/health`, { signal: AbortSignal.timeout(3000) });
    return true;
  } catch {
    return false;
  }
}

export async function triggerFullPipeline(
  clinicianDID?: string
): Promise<PipelineResult> {
  return fetchJSON<PipelineResult>(EA_API, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      id: `demo-${Date.now()}`,
      data: { clinicianDID: clinicianDID || "did:tlh:clinician-789" },
    }),
  });
}
