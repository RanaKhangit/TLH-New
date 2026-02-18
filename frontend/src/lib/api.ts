const PROVER_API =
  process.env.NEXT_PUBLIC_PROVER_API_URL || "http://localhost:8787";
const EA_API = process.env.NEXT_PUBLIC_EA_URL || "http://localhost:8788";

export interface DecoVerifyResult {
  result: "PASS" | "FAIL";
  reason?: string;
  proofId: string;
  verificationType: string;
  completedAt: string;
  gmcRefNo?: string;
  registrationStatus?: string;
  attestation?: DecoAttestation;
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
    privateTxHash?: string;
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

export async function fetchDecoVerify(
  surname?: string,
  givenName?: string
): Promise<DecoVerifyResult> {
  let url = `${PROVER_API}/deco/verify`;
  if (surname && givenName) {
    const params = new URLSearchParams({ surname, givenName });
    url = `${url}?${params}`;
  }
  return fetchJSON<DecoVerifyResult>(url);
}

export async function fetchDecoAttestation(
  surname?: string,
  givenName?: string
): Promise<DecoAttestation> {
  let url = `${PROVER_API}/deco/attestation`;
  if (surname && givenName) {
    const params = new URLSearchParams({ surname, givenName });
    url = `${url}?${params}`;
  }
  return fetchJSON<DecoAttestation>(url);
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

export interface DoctorEntry {
  surname: string;
  givenName: string;
  gmcRefNo: string;
  registrationStatus: string;
}

export async function fetchDoctors(): Promise<DoctorEntry[]> {
  return fetchJSON<DoctorEntry[]>(`${PROVER_API}/gmc/doctors`);
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
  clinicianDID?: string,
  surname?: string,
  givenName?: string
): Promise<PipelineResult> {
  return fetchJSON<PipelineResult>("/api/pipeline", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ clinicianDID, surname, givenName }),
  });
}
