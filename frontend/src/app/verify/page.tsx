"use client";

import { useState, useEffect } from "react";
import {
  triggerFullPipeline,
  fetchDoctors,
  type PipelineResult,
  type DoctorEntry,
} from "@/lib/api";
import { useVerifyAttestation, useTrustVerifyAttestation } from "@/hooks/use-attestation-verifier";
import { useIsCredentialValid } from "@/hooks/use-credential-registry";
import { etherscanTxUrl, formatBytes32, toBytes32 } from "@/lib/utils";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

export default function VerifyPage() {
  const [doctors, setDoctors] = useState<DoctorEntry[]>([]);
  const [doctorsLoading, setDoctorsLoading] = useState(true);
  const [pipeline, setPipeline] = useState<PipelineResult | null>(null);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedName, setSelectedName] = useState(0);

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
    try {
      const result = await triggerFullPipeline(clinicianDID, surname, givenName);
      setPipeline(result);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Pipeline failed");
    }
    setRunning(false);
  }

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
          The External Adapter will: look up {givenName} {surname} in the GMC
          register, generate and verify a DECO attestation, build ADR-002
          predicateData, sign chain-bound digests, and submit to both Sepolia
          (shared anchor) and Private Chain (trust) in a single atomic operation.
        </p>

        <button
          onClick={runPipeline}
          disabled={running || doctorsLoading || doctors.length === 0}
          className="w-full rounded-lg bg-accent px-4 py-3 text-sm font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50"
        >
          {doctorsLoading
            ? "Loading Doctors..."
            : running
              ? "Running Pipeline..."
              : "Verify & Submit On-Chain"}
        </button>
      </Card>

      {/* Loading state */}
      {running && (
        <Card>
          <div className="space-y-3">
            <Skeleton className="h-3 w-48" />
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-1/2" />
          </div>
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
          {/* Pipeline results */}
          <Card>
            <h2 className="text-sm font-semibold text-foreground mb-4">
              Pipeline Results
            </h2>
            <dl className="space-y-3 text-sm">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Subject DID</dt>
                <dd className="font-mono text-foreground text-xs">
                  {clinicianDID}
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
              clinicianDID={clinicianDID}
              privateChainAvailable={!!pipeline.data.privateTxHash}
            />
          )}
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
      <p className="text-xs text-muted-foreground mb-4">
        Reading back from both chains to confirm data landed on-chain.
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
            <Badge variant="muted">Not Found</Badge>
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
            <Badge variant="warning">Unavailable</Badge>
          ) : trustOk ? (
            <Badge variant="success">Confirmed</Badge>
          ) : (
            <Badge variant="muted">Not Found</Badge>
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
            <Badge variant="warning">Unavailable</Badge>
          ) : credOk ? (
            <Badge variant="success">Credential Valid</Badge>
          ) : (
            <Badge variant="muted">Not Valid</Badge>
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
            <Badge variant="warning">Sepolia Only</Badge>
          ) : (
            <Badge variant="danger">Verification Failed</Badge>
          )}
        </div>
      </div>
    </Card>
  );
}
