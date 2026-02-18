"use client";

import { useState } from "react";
import {
  fetchDecoVerify,
  fetchGMCLookup,
  triggerFullPipeline,
  type DecoVerifyResult,
  type GMCRecord,
  type PipelineResult,
} from "@/lib/api";
import { etherscanTxUrl, formatBytes32 } from "@/lib/utils";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

const DEMO_NAMES = [
  { surname: "Adfcds", givenName: "Azhar" },
  { surname: "Fsofkdoo", givenName: "Rosalind" },
  { surname: "Hslllsp", givenName: "Keith" },
  { surname: "Bskeodk", givenName: "Alison" },
];

export default function VerifyPage() {
  // Step 1: GMC Lookup
  const [gmcResults, setGmcResults] = useState<GMCRecord[] | null>(null);
  const [gmcLoading, setGmcLoading] = useState(false);
  const [gmcError, setGmcError] = useState<string | null>(null);

  // Step 2: DECO Verify (generates attestation + verifies it)
  const [decoResult, setDecoResult] = useState<DecoVerifyResult | null>(null);
  const [decoLoading, setDecoLoading] = useState(false);
  const [decoError, setDecoError] = useState<string | null>(null);

  // Step 3: Submit On-Chain
  const [pipeline, setPipeline] = useState<PipelineResult | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [pipelineError, setPipelineError] = useState<string | null>(null);

  const [selectedName, setSelectedName] = useState(0);

  async function lookupGMC() {
    setGmcLoading(true);
    setGmcResults(null);
    setGmcError(null);
    // Reset downstream steps
    setDecoResult(null);
    setDecoError(null);
    setPipeline(null);
    setPipelineError(null);
    try {
      const { surname, givenName } = DEMO_NAMES[selectedName];
      const results = await fetchGMCLookup(surname, givenName);
      setGmcResults(results);
    } catch (e) {
      setGmcError(
        e instanceof Error ? e.message : "GMC lookup failed. Is the Prover API running?"
      );
    }
    setGmcLoading(false);
  }

  async function verifyDeco() {
    setDecoLoading(true);
    setDecoResult(null);
    setDecoError(null);
    // Reset downstream
    setPipeline(null);
    setPipelineError(null);
    try {
      const { surname, givenName } = DEMO_NAMES[selectedName];
      const result = await fetchDecoVerify(surname, givenName);
      setDecoResult(result);
    } catch (e) {
      setDecoError(
        e instanceof Error ? e.message : "DECO verification failed"
      );
    }
    setDecoLoading(false);
  }

  async function submitOnChain() {
    setSubmitting(true);
    setPipelineError(null);
    setPipeline(null);
    try {
      const { surname, givenName } = DEMO_NAMES[selectedName];
      const clinicianDID = `did:tlh:${givenName.toLowerCase()}-${surname.toLowerCase()}`;
      const result = await triggerFullPipeline(clinicianDID, surname, givenName);
      setPipeline(result);
    } catch (e) {
      setPipelineError(
        e instanceof Error ? e.message : "Pipeline submission failed"
      );
    }
    setSubmitting(false);
  }

  const { surname, givenName } = DEMO_NAMES[selectedName];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-foreground">
          Verify Credential
        </h1>
        <p className="text-sm text-muted-foreground mt-1">
          End-to-end pipeline: GMC lookup &rarr; DECO attestation &rarr;
          on-chain submission
        </p>
      </div>

      {/* Doctor Selector */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-3">
          Select Doctor
        </h2>
        <select
          value={selectedName}
          onChange={(e) => {
            setSelectedName(Number(e.target.value));
            // Reset all steps when doctor changes
            setGmcResults(null);
            setGmcError(null);
            setDecoResult(null);
            setDecoError(null);
            setPipeline(null);
            setPipelineError(null);
          }}
          className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground"
        >
          {DEMO_NAMES.map((n, i) => (
            <option key={i} value={i}>
              {n.givenName} {n.surname}
            </option>
          ))}
        </select>
      </Card>

      {/* Step 1: GMC Lookup */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-foreground">
            <span className="text-accent mr-2">Step 1</span>
            GMC Registry Lookup
          </h2>
          <button
            onClick={lookupGMC}
            disabled={gmcLoading}
            className="rounded-lg bg-muted px-4 py-2 text-xs font-medium text-foreground hover:bg-muted/80 transition-colors disabled:opacity-50"
          >
            {gmcLoading ? "Looking up..." : "Lookup GMC Registration"}
          </button>
        </div>

        {gmcLoading && (
          <div className="space-y-2">
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-3 w-full" />
          </div>
        )}

        {gmcError && (
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            {gmcError}
          </div>
        )}

        {gmcResults && gmcResults.length > 0 && !gmcLoading && (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted-foreground">
                  <th className="pb-2 pr-4">GMC Ref</th>
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Qualification</th>
                  <th className="pb-2 pr-4">Registration Status</th>
                </tr>
              </thead>
              <tbody>
                {gmcResults.map((r, i) => (
                  <tr key={i} className="border-b border-border/50">
                    <td className="py-2 pr-4 font-mono">{r.gmcRefNo}</td>
                    <td className="py-2 pr-4">
                      {r.givenName} {r.surname}
                    </td>
                    <td className="py-2 pr-4 text-muted-foreground">
                      {r.qualification}
                    </td>
                    <td className="py-2 pr-4">
                      <Badge
                        variant={
                          r.registrationStatus?.includes("Licence")
                            ? "success"
                            : "danger"
                        }
                      >
                        {r.registrationStatus}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {gmcResults && gmcResults.length === 0 && (
          <div className="text-sm text-muted-foreground">No records found.</div>
        )}
      </Card>

      {/* Step 2: DECO Attestation Verification */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-foreground">
            <span className="text-accent mr-2">Step 2</span>
            DECO Attestation Verification
          </h2>
          <button
            onClick={verifyDeco}
            disabled={decoLoading}
            className="rounded-lg bg-accent px-4 py-2 text-xs font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50"
          >
            {decoLoading ? "Generating & Verifying..." : "Generate & Verify Attestation"}
          </button>
        </div>

        <p className="text-xs text-muted-foreground mb-4">
          Generates a DECO attestation for {givenName} {surname}&apos;s GMC
          data, signs it with the prover key, then cryptographically verifies
          the signature and registration predicate.
        </p>

        {decoLoading && (
          <div className="space-y-2">
            <Skeleton className="h-3 w-24" />
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-10 w-full" />
          </div>
        )}

        {decoError && (
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            {decoError}
          </div>
        )}

        {decoResult && !decoLoading && (
          <div className="space-y-4">
            {/* Attestation data */}
            {decoResult.attestation && (
              <div className="space-y-2 text-sm">
                <h3 className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
                  Attestation
                </h3>
                <dl className="space-y-2">
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Signature Scheme</dt>
                    <dd className="font-mono text-foreground">
                      {decoResult.attestation.signature_scheme}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-muted-foreground mb-1">Signature</dt>
                    <dd className="font-mono text-xs text-foreground bg-muted p-2 rounded break-all">
                      {formatBytes32(decoResult.attestation.signature_hex)}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-muted-foreground mb-1">Public Key</dt>
                    <dd className="font-mono text-xs text-foreground bg-muted p-2 rounded break-all">
                      {formatBytes32(decoResult.attestation.public_key_hex)}
                    </dd>
                  </div>
                </dl>
              </div>
            )}

            {/* Verification result */}
            <div className="border-t border-border pt-4 space-y-2 text-sm">
              <h3 className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
                Verification Result
              </h3>
              <div className="flex items-center gap-3">
                <span className="text-muted-foreground">Result:</span>
                <Badge
                  variant={
                    decoResult.result === "PASS" ? "success" : "danger"
                  }
                >
                  {decoResult.result}
                </Badge>
              </div>
              {decoResult.reason && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Reason</dt>
                  <dd className="text-foreground text-right max-w-[60%]">
                    {decoResult.reason}
                  </dd>
                </div>
              )}
              {decoResult.gmcRefNo && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">GMC Ref (from proof)</dt>
                  <dd className="font-mono text-foreground">
                    {decoResult.gmcRefNo}
                  </dd>
                </div>
              )}
              {decoResult.registrationStatus && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">
                    Registration (from proof)
                  </dt>
                  <dd className="text-foreground">
                    <Badge
                      variant={
                        decoResult.registrationStatus.includes("Licence")
                          ? "success"
                          : "danger"
                      }
                    >
                      {decoResult.registrationStatus}
                    </Badge>
                  </dd>
                </div>
              )}
              {decoResult.proofId && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Proof ID</dt>
                  <dd className="font-mono text-foreground">
                    {decoResult.proofId}
                  </dd>
                </div>
              )}
              {decoResult.completedAt && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Verified At</dt>
                  <dd className="text-foreground">{decoResult.completedAt}</dd>
                </div>
              )}
            </div>
          </div>
        )}
      </Card>

      {/* Step 3: Submit On-Chain */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-foreground">
            <span className="text-accent mr-2">Step 3</span>
            Submit On-Chain
          </h2>
          <button
            onClick={submitOnChain}
            disabled={submitting}
            className="rounded-lg bg-muted px-4 py-2 text-xs font-medium text-foreground hover:bg-muted/80 transition-colors disabled:opacity-50"
          >
            {submitting ? "Submitting..." : "Submit to Sepolia"}
          </button>
        </div>

        <p className="text-xs text-muted-foreground mb-4">
          Runs the full pipeline for {givenName} {surname}: EA verifies DECO
          attestation, builds ADR-002 predicateData, signs chain-bound digest,
          and calls submitAttestation() on the AttestationVerifier contract.
        </p>

        {submitting && (
          <div className="space-y-2">
            <Skeleton className="h-3 w-32" />
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
          </div>
        )}

        {pipelineError && (
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            {pipelineError}
          </div>
        )}

        {pipeline && !submitting && (
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Subject DID</dt>
              <dd className="font-mono text-foreground text-xs">
                did:tlh:{givenName.toLowerCase()}-{surname.toLowerCase()}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Verification</dt>
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
              <dt className="text-muted-foreground mb-1">Transaction</dt>
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
          </dl>
        )}
      </Card>
    </div>
  );
}
