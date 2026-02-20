"use client";

import { useState, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import {
  triggerFullPipeline,
  fetchDoctors,
  fetchGMCLookup,
  type PipelineResult,
  type DoctorEntry,
  type GMCRecord,
} from "@/lib/api";
import { useVerifyAttestation, useTrustVerifyAttestation } from "@/hooks/use-attestation-verifier";
import { useIsCredentialValid } from "@/hooks/use-credential-registry";
import { etherscanTxUrl, formatBytes32, toBytes32 } from "@/lib/utils";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";

export default function VerifyPage() {
  return (
    <Suspense fallback={<VerifyPageSkeleton />}>
      <VerifyPageContent />
    </Suspense>
  );
}

function VerifyPageSkeleton() {
  return (
    <div className="space-y-8">
      <div>
        <Skeleton className="h-8 w-48 mb-2" />
        <Skeleton className="h-4 w-72" />
      </div>
      <Card>
        <Skeleton className="h-10 w-full mb-4" />
        <Skeleton className="h-10 w-32" />
      </Card>
    </div>
  );
}

function VerifyPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => { document.title = "Verify Credential | Trust Layer Health"; }, []);

  // Restore pipeline result from URL search params on mount (validated)
  const HEX_RE = /^0x[0-9a-fA-F]+$/;
  const rawAttId = searchParams.get("attestationId");
  const rawTxHash = searchParams.get("txHash");
  const rawProofId = searchParams.get("proofId");
  const rawResult = searchParams.get("result");
  const rawPrivateTxHash = searchParams.get("privateTxHash");
  const rawDoctorIndex = searchParams.get("doctor");
  const rawDid = searchParams.get("did");

  const initialAttestationId = rawAttId && HEX_RE.test(rawAttId) ? rawAttId : null;
  const initialTxHash = rawTxHash && HEX_RE.test(rawTxHash) ? rawTxHash : null;
  const initialProofId = rawProofId && /^[0-9a-fA-F]+$/.test(rawProofId) ? rawProofId : null;
  const initialResult = rawResult === "PASS" || rawResult === "FAIL" ? rawResult : null;
  const initialPrivateTxHash = rawPrivateTxHash && HEX_RE.test(rawPrivateTxHash) ? rawPrivateTxHash : null;
  const initialDoctorIndex = rawDoctorIndex && /^\d+$/.test(rawDoctorIndex) ? rawDoctorIndex : null;
  const initialDid = rawDid && /^did:[a-z]+:[a-zA-Z0-9._:-]+$/.test(rawDid) ? rawDid : null;

  const [doctors, setDoctors] = useState<DoctorEntry[]>([]);
  const [doctorsLoading, setDoctorsLoading] = useState(true);
  const [pipeline, setPipeline] = useState<PipelineResult | null>(
    initialAttestationId && initialTxHash
      ? {
          jobRunID: "restored",
          statusCode: 200,
          data: {
            result: initialTxHash,
            txHash: initialTxHash,
            privateTxHash: initialPrivateTxHash || undefined,
            proofId: initialProofId || "",
            attestationId: initialAttestationId,
            verificationResult: initialResult || "PASS",
          },
        }
      : null
  );
  const [running, setRunning] = useState(false);
  const [pipelineStep, setPipelineStep] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [gmcRecord, setGmcRecord] = useState<GMCRecord | null>(null);
  const [selectedName, setSelectedName] = useState(initialDoctorIndex ? Number(initialDoctorIndex) : 0);
  const [restoredDID, setRestoredDID] = useState<string | null>(
    initialAttestationId && initialTxHash && initialDid ? initialDid : null
  );

  useEffect(() => {
    fetchDoctors()
      .then(setDoctors)
      .catch(() => setError("Failed to load doctor list"))
      .finally(() => setDoctorsLoading(false));
  }, []);

  const doctor = doctors[selectedName];
  const surname = doctor?.surname ?? "";
  const givenName = doctor?.givenName ?? "";
  const clinicianDID = `did:tlh:${givenName.toLowerCase()}-${surname.toLowerCase()}`;

  async function runPipeline() {
    setRunning(true);
    setError(null);
    setPipeline(null);
    setRestoredDID(null);
    setPipelineStep(0);
    setGmcRecord(null);
    try {
      // Simulate step progression while awaiting the single API call
      const stepTimer = setInterval(() => {
        setPipelineStep((s) => Math.min(s + 1, 4));
      }, 3000);

      const result = await triggerFullPipeline(clinicianDID, surname, givenName);
      clearInterval(stepTimer);
      setPipelineStep(5);
      setPipeline(result);
      toast.success("Pipeline complete — attestation submitted to both chains");

      // Fetch full GMC record for display
      fetchGMCLookup(surname, givenName)
        .then((records) => { if (records.length > 0) setGmcRecord(records[0]); })
        .catch(() => { /* non-critical */ });

      // Persist to URL so results survive navigation
      const params = new URLSearchParams({
        attestationId: result.data.attestationId,
        txHash: result.data.txHash,
        proofId: result.data.proofId,
        result: result.data.verificationResult,
        doctor: String(selectedName),
        did: clinicianDID,
      });
      if (result.data.privateTxHash) {
        params.set("privateTxHash", result.data.privateTxHash);
      }
      router.replace(`/verify?${params.toString()}`, { scroll: false });
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Pipeline failed";
      setError(msg);
      toast.error(`Pipeline failed: ${msg}`);
    }
    setRunning(false);
  }

  // Use restored DID if we loaded from URL, otherwise use current selection
  const activeDID = restoredDID ?? clinicianDID;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-foreground">
          Verify Credential
        </h1>
        <p className="text-sm text-muted-foreground mt-1">
          Single-click pipeline: DECO verify + sign + submit to both chains
        </p>
      </div>

      {/* Doctor selector + trigger button */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-3">
          Select Doctor
        </h2>
        <select
          value={selectedName}
          onChange={(e) => {
            setSelectedName(Number(e.target.value));
            setPipeline(null);
            setError(null);
            setRestoredDID(null);
            setGmcRecord(null);
            router.replace("/verify", { scroll: false });
          }}
          className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground mb-4"
        >
          {doctors.map((d, i) => (
            <option key={i} value={i}>
              {d.givenName} {d.surname}
            </option>
          ))}
        </select>

        <p className="text-xs text-muted-foreground mb-4">
          This will verify {givenName} {surname}&apos;s GMC registration and record the result permanently on both chains.
        </p>

        <button
          onClick={runPipeline}
          disabled={running || doctorsLoading || doctors.length === 0}
          className="w-full rounded-lg bg-accent px-4 py-3 text-sm font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          {running && (
            <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          )}
          {doctorsLoading
            ? "Loading Doctors..."
            : running
              ? "Verifying..."
              : "Verify & Submit On-Chain"}
        </button>
      </Card>

      {/* Pipeline progress stepper */}
      {running && (
        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-3">
            Pipeline Running...
          </h2>
          <div className="space-y-1">
            {[
              "Looking up doctor in GMC register",
              "Generating DECO attestation",
              "Verifying proof via Prover API",
              "Signing chain-bound digests",
              "Submitting to Sepolia + Private Chain",
            ].map((step, i) => (
              <div key={i} className="flex items-center gap-3 py-1.5">
                {i < pipelineStep ? (
                  <span className="flex h-5 w-5 items-center justify-center rounded-full bg-success text-[10px] text-white font-bold shrink-0">&#10003;</span>
                ) : i === pipelineStep ? (
                  <span className="h-5 w-5 rounded-full border-2 border-accent bg-accent/20 animate-pulse shrink-0" />
                ) : (
                  <span className="h-5 w-5 rounded-full border-2 border-border shrink-0" />
                )}
                <span className={`text-sm ${i < pipelineStep ? "text-foreground" : i === pipelineStep ? "text-accent font-medium" : "text-muted-foreground"}`}>
                  {step}
                </span>
              </div>
            ))}
          </div>
          <p className="text-xs text-muted-foreground mt-4">
            This may take 10-30 seconds depending on chain confirmation times.
          </p>
        </Card>
      )}

      {/* Error */}
      {error && (
        <Card>
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            {error}
          </div>
        </Card>
      )}

      {/* Results */}
      {pipeline && !running && (
        <>
          {/* GMC Lookup Result */}
          <Card>
            <h2 className="text-sm font-semibold text-foreground mb-4">
              GMC Lookup Result
            </h2>
            {gmcRecord ? (
              <dl className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Name</dt>
                  <dd className="text-foreground">{gmcRecord.givenName} {gmcRecord.surname}</dd>
                </div>
                <div className="flex justify-between items-center">
                  <dt className="text-muted-foreground">GMC Reference No.</dt>
                  <dd className="font-mono text-foreground">{gmcRecord.gmcRefNo}</dd>
                </div>
                <div className="flex justify-between items-center">
                  <dt className="text-muted-foreground">Registration Status</dt>
                  <dd className="flex items-center gap-2">
                    <Badge variant={gmcRecord.registrationStatus?.includes("Licence") ? "success" : "danger"}>
                      {gmcRecord.registrationStatus?.includes("Licence") ? "LICENSED" : "NOT LICENSED"}
                    </Badge>
                    <span className="text-xs text-muted-foreground hidden sm:inline">
                      {!gmcRecord.registrationStatus?.includes("Licence") && `(${gmcRecord.registrationStatus})`}
                    </span>
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Qualification</dt>
                  <dd className="text-foreground">{gmcRecord.qualification || <span className="text-muted-foreground/70 italic">Not in GMC register</span>}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Place of Qualification</dt>
                  <dd className="text-foreground">{gmcRecord.qualPlace || <span className="text-muted-foreground/70 italic">Not in GMC register</span>}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Year of Qualification</dt>
                  <dd className="text-foreground">{gmcRecord.qualYear || <span className="text-muted-foreground/70 italic">Not in GMC register</span>}</dd>
                </div>
                <div className="flex justify-between items-center">
                  <dt className="text-muted-foreground">Revalidation Status</dt>
                  <dd className="text-foreground">{gmcRecord.revalidationStatus || <span className="text-muted-foreground/70 italic">Not in GMC register</span>}</dd>
                </div>
              </dl>
            ) : (
              <div className="space-y-2">
                <Skeleton className="h-3 w-48" />
                <Skeleton className="h-3 w-64" />
                <Skeleton className="h-3 w-56" />
              </div>
            )}
          </Card>

          {/* Pipeline results */}
          <Card>
            <h2 className="text-sm font-semibold text-foreground mb-4">
              Pipeline Results
            </h2>
            <dl className="space-y-3 text-sm">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Subject DID</dt>
                <dd className="font-mono text-foreground text-xs">
                  {activeDID}
                </dd>
              </div>
              <div className="flex justify-between items-center">
                <dt className="text-muted-foreground">DECO Verification</dt>
                <dd>
                  <Badge
                    variant={
                      pipeline.data.verificationResult === "PASS"
                        ? "success"
                        : "danger"
                    }
                  >
                    {pipeline.data.verificationResult}
                  </Badge>
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Proof ID</dt>
                <dd className="font-mono text-foreground">
                  {pipeline.data.proofId}
                </dd>
              </div>
              {pipeline.data.attestationId && (
                <div>
                  <dt className="text-muted-foreground mb-1">Attestation ID</dt>
                  <dd className="font-mono text-xs text-foreground bg-muted p-2 rounded break-all">
                    {pipeline.data.attestationId}
                  </dd>
                </div>
              )}
              <div>
                <dt className="text-muted-foreground mb-1">
                  Sepolia Transaction (Shared Anchor)
                </dt>
                <dd>
                  <a
                    href={etherscanTxUrl(pipeline.data.txHash)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="font-mono text-xs text-accent hover:underline break-all"
                  >
                    {pipeline.data.txHash}
                  </a>
                </dd>
              </div>
              {pipeline.data.privateTxHash && (
                <div>
                  <dt className="text-muted-foreground mb-1">
                    Private Chain Transaction (Trust)
                  </dt>
                  <dd className="font-mono text-xs text-foreground bg-muted p-2 rounded break-all">
                    {pipeline.data.privateTxHash}
                    <span className="block text-[10px] text-muted-foreground mt-1">
                      Private chain — no public block explorer available
                    </span>
                  </dd>
                </div>
              )}
              {!pipeline.data.privateTxHash && (
                <div className="flex justify-between items-center">
                  <dt className="text-muted-foreground">
                    Private Chain Transaction
                  </dt>
                  <dd>
                    <Badge variant="warning">Unavailable</Badge>
                  </dd>
                </div>
              )}
            </dl>
          </Card>

          {/* On-chain verification readback */}
          {pipeline.data.attestationId && (
            <OnChainVerification
              attestationId={pipeline.data.attestationId as `0x${string}`}
              clinicianDID={activeDID}
              privateChainAvailable={!!pipeline.data.privateTxHash}
            />
          )}

          {/* Export + Explorer links */}
          <Card>
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-sm font-semibold text-foreground">
                  Explore This DID
                </h2>
                <p className="text-xs text-muted-foreground mt-1">
                  View full history and linked data in Explorer
                </p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    const json = JSON.stringify({
                      did: activeDID,
                      attestationId: pipeline.data.attestationId,
                      proofId: pipeline.data.proofId,
                      verificationResult: pipeline.data.verificationResult,
                      sepoliaTxHash: pipeline.data.txHash,
                      privateTxHash: pipeline.data.privateTxHash ?? null,
                      exportedAt: new Date().toISOString(),
                    }, null, 2);
                    const blob = new Blob([json], { type: "application/json" });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement("a");
                    a.href = url;
                    a.download = `attestation-${pipeline.data.attestationId.slice(0, 10)}.json`;
                    a.click();
                    URL.revokeObjectURL(url);
                    toast.success("Attestation JSON exported");
                  }}
                  className="rounded-lg bg-muted px-4 py-2 text-sm font-medium text-foreground hover:bg-muted/80 transition-colors"
                >
                  Export JSON
                </button>
                <a
                  href={`/explorer?did=${encodeURIComponent(activeDID)}&attestationId=${pipeline.data.attestationId}`}
                  className="rounded-lg bg-muted px-4 py-2 text-sm font-medium text-foreground hover:bg-muted/80 transition-colors"
                >
                  View in Explorer →
                </a>
              </div>
            </div>
          </Card>
        </>
      )}
    </div>
  );
}

function OnChainVerification({
  attestationId,
  clinicianDID,
  privateChainAvailable,
}: {
  attestationId: `0x${string}`;
  clinicianDID: string;
  privateChainAvailable: boolean;
}) {
  const subjectDID = toBytes32(clinicianDID);
  const predicateType = toBytes32("GMC_REGISTERED");

  const sepoliaAttestation = useVerifyAttestation(attestationId);

  // Only call private chain hooks if chain is available
  const trustAttestation = useTrustVerifyAttestation(
    privateChainAvailable ? attestationId : undefined
  );
  const credentialValid = useIsCredentialValid(
    privateChainAvailable ? subjectDID : undefined,
    privateChainAvailable ? predicateType : undefined
  );

  // Treat offline chain as immediate "unavailable" state
  const privateChainOffline = !privateChainAvailable;

  const sepoliaOk = sepoliaAttestation.data && sepoliaAttestation.data[0];
  const trustOk = !privateChainOffline && trustAttestation.data && trustAttestation.data[0];
  const credOk = !privateChainOffline && credentialValid.data === true;

  const anyLoading =
    sepoliaAttestation.isLoading ||
    (!privateChainOffline && trustAttestation.isLoading) ||
    (!privateChainOffline && credentialValid.isLoading);

  return (
    <Card>
      <h2 className="text-sm font-semibold text-foreground mb-2">
        On-Chain Verification (Live Readback)
      </h2>
      <p className="text-xs text-muted-foreground mb-2">
        Reading back from both chains to confirm data landed on-chain.
      </p>
      <p className="text-xs text-muted-foreground/70 mb-4">
        Sepolia typically takes 30-60 seconds for block finality. Private Chain confirms in 5-10 seconds.
      </p>

      {anyLoading && (
        <div className="space-y-2 mb-4">
          <Skeleton className="h-3 w-48" />
          <Skeleton className="h-3 w-64" />
          <Skeleton className="h-3 w-56" />
        </div>
      )}

      <div className="space-y-3">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">
            Sepolia AttestationVerifier
          </span>
          {sepoliaAttestation.isLoading ? (
            <span className="text-xs text-muted-foreground">Reading...</span>
          ) : sepoliaAttestation.error ? (
            <Badge variant="danger">Error</Badge>
          ) : sepoliaOk ? (
            <Badge variant="success">Confirmed</Badge>
          ) : (
            <Badge variant="muted">Confirming...</Badge>
          )}
        </div>

        {sepoliaOk && sepoliaAttestation.data && (
          <div className="ml-4 space-y-1 text-xs text-muted-foreground border-l border-border pl-3">
            <div>
              Result:{" "}
              <Badge variant={sepoliaAttestation.data[3] ? "success" : "danger"}>
                {sepoliaAttestation.data[3] ? "PASS" : "FAIL"}
              </Badge>
            </div>
            <div>Subject DID: {formatBytes32(sepoliaAttestation.data[1])}</div>
          </div>
        )}

        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">
            Private Chain TrustAttestationVerifier
          </span>
          {privateChainOffline ? (
            <Badge variant="warning">Offline</Badge>
          ) : trustAttestation.isLoading ? (
            <span className="text-xs text-muted-foreground">Reading...</span>
          ) : trustAttestation.error ? (
            <Badge variant="muted">Unavailable</Badge>
          ) : trustOk ? (
            <Badge variant="success">Confirmed</Badge>
          ) : (
            <Badge variant="muted">Confirming...</Badge>
          )}
        </div>

        {trustOk && trustAttestation.data && (
          <div className="ml-4 space-y-1 text-xs text-muted-foreground border-l border-border pl-3">
            <div>
              Result:{" "}
              <Badge variant={trustAttestation.data[3] ? "success" : "danger"}>
                {trustAttestation.data[3] ? "PASS" : "FAIL"}
              </Badge>
            </div>
            <div>Subject DID: {formatBytes32(trustAttestation.data[1])}</div>
          </div>
        )}

        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">
            Private Chain CredentialRegistry
          </span>
          {privateChainOffline ? (
            <Badge variant="warning">Offline</Badge>
          ) : credentialValid.isLoading ? (
            <span className="text-xs text-muted-foreground">Reading...</span>
          ) : credentialValid.error ? (
            <Badge variant="muted">Unavailable</Badge>
          ) : credOk ? (
            <Badge variant="success">Credential Valid</Badge>
          ) : (
            <Badge variant="muted">Confirming...</Badge>
          )}
        </div>

        <div className="border-t border-border pt-3 mt-3 flex items-center justify-between">
          <span className="text-sm font-medium text-foreground">
            Dual-Chain Status
          </span>
          {anyLoading ? (
            <Badge variant="muted">Verifying...</Badge>
          ) : sepoliaOk && trustOk ? (
            <Badge variant="success">Both Chains Confirmed</Badge>
          ) : sepoliaOk && privateChainOffline ? (
            <Badge variant="warning">Sepolia Only (Private Chain Offline)</Badge>
          ) : sepoliaOk ? (
            <Badge variant="muted">Sepolia Only</Badge>
          ) : (
            <Badge variant="muted">Confirming on Sepolia...</Badge>
          )}
        </div>
      </div>
    </Card>
  );
}
