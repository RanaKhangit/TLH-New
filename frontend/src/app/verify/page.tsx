"use client";

import { useState } from "react";
import {
  fetchDecoVerify,
  fetchDecoAttestation,
  fetchGMCLookup,
  triggerFullPipeline,
  type DecoVerifyResult,
  type DecoAttestation,
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
  const [attestation, setAttestation] = useState<DecoAttestation | null>(null);
  const [loadingAtt, setLoadingAtt] = useState(false);
  const [attError, setAttError] = useState<string | null>(null);
  const [verifyResult, setVerifyResult] = useState<DecoVerifyResult | null>(null);
  const [verifying, setVerifying] = useState(false);
  const [verifyError, setVerifyError] = useState<string | null>(null);
  const [pipeline, setPipeline] = useState<PipelineResult | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [pipelineError, setPipelineError] = useState<string | null>(null);
  const [gmcResults, setGmcResults] = useState<GMCRecord[] | null>(null);
  const [gmcLoading, setGmcLoading] = useState(false);
  const [gmcError, setGmcError] = useState<string | null>(null);
  const [selectedName, setSelectedName] = useState(0);

  async function loadAttestation() {
    setLoadingAtt(true);
    setAttError(null);
    try {
      const att = await fetchDecoAttestation();
      setAttestation(att);
    } catch (e) {
      setAttestation(null);
      setAttError(e instanceof Error ? e.message : "Failed to load attestation. Is the Prover API running?");
    }
    setLoadingAtt(false);
  }

  async function runVerification() {
    setVerifying(true);
    setVerifyError(null);
    setVerifyResult(null);
    try {
      const result = await fetchDecoVerify();
      setVerifyResult(result);
    } catch (e) {
      setVerifyError(e instanceof Error ? e.message : "Verification failed");
    }
    setVerifying(false);
  }

  async function submitOnChain() {
    setSubmitting(true);
    setPipelineError(null);
    setPipeline(null);
    try {
      // Pass the selected doctor's name as a DID so the on-chain
      // attestation is linked to the specific clinician
      const { surname, givenName } = DEMO_NAMES[selectedName];
      const clinicianDID = `did:tlh:${givenName.toLowerCase()}-${surname.toLowerCase()}`;
      const result = await triggerFullPipeline(clinicianDID);
      setPipeline(result);
    } catch (e) {
      setPipelineError(
        e instanceof Error ? e.message : "Pipeline submission failed"
      );
    }
    setSubmitting(false);
  }

  async function lookupGMC() {
    setGmcLoading(true);
    setGmcResults(null);
    setGmcError(null);
    try {
      const { surname, givenName } = DEMO_NAMES[selectedName];
      const results = await fetchGMCLookup(surname, givenName);
      setGmcResults(results);
    } catch (e) {
      setGmcResults(null);
      setGmcError(e instanceof Error ? e.message : "GMC lookup failed. Is the Prover API running?");
    }
    setGmcLoading(false);
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-foreground">
          Verify Credential
        </h1>
        <p className="text-sm text-muted-foreground mt-1">
          Run DECO attestation verification and submit results on-chain
        </p>
      </div>

      {/* Load attestation */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-foreground">
            DECO Attestation Data
          </h2>
          <button
            onClick={loadAttestation}
            disabled={loadingAtt}
            className="rounded-lg bg-muted px-4 py-2 text-xs font-medium text-foreground hover:bg-muted/80 transition-colors disabled:opacity-50"
          >
            {loadingAtt ? "Loading..." : "Load Attestation"}
          </button>
        </div>
        {attError && (
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            {attError}
          </div>
        )}
        {loadingAtt && (
          <div className="space-y-2">
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        )}
        {attestation && !loadingAtt && (
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Signature Scheme</dt>
              <dd className="font-mono text-foreground">
                {attestation.signature_scheme}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Attestation Scheme</dt>
              <dd className="font-mono text-foreground">
                {attestation.attestation_scheme}
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground mb-1">Signature</dt>
              <dd className="font-mono text-xs text-foreground bg-muted p-2 rounded break-all">
                {formatBytes32(attestation.signature_hex)}
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground mb-1">Public Key</dt>
              <dd className="font-mono text-xs text-foreground bg-muted p-2 rounded break-all">
                {formatBytes32(attestation.public_key_hex)}
              </dd>
            </div>
          </dl>
        )}
      </Card>

      {/* Verify */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-foreground">
            Verification
          </h2>
          <button
            onClick={runVerification}
            disabled={verifying}
            className="rounded-lg bg-accent px-4 py-2 text-xs font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50"
          >
            {verifying ? "Verifying..." : "Verify Attestation"}
          </button>
        </div>

        {verifyError && (
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            {verifyError}
          </div>
        )}

        {verifying && (
          <div className="space-y-2">
            <Skeleton className="h-3 w-24" />
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
          </div>
        )}

        {verifyResult && !verifying && (
          <div className="space-y-3">
            <div className="flex items-center gap-3">
              <span className="text-sm text-muted-foreground">Result:</span>
              <Badge
                variant={
                  verifyResult.result === "PASS" ? "success" : "danger"
                }
              >
                {verifyResult.result}
              </Badge>
            </div>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Proof ID</dt>
                <dd className="font-mono text-foreground">
                  {verifyResult.proofId}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Completed At</dt>
                <dd className="text-foreground">{verifyResult.completedAt}</dd>
              </div>
            </dl>
          </div>
        )}
      </Card>

      {/* Submit on-chain */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-foreground">
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

        {pipelineError && (
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            {pipelineError}
          </div>
        )}

        {submitting && (
          <div className="space-y-2">
            <Skeleton className="h-3 w-32" />
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
          </div>
        )}

        {pipeline && !submitting && (
          <dl className="space-y-2 text-sm">
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

      {/* GMC Lookup */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-4">
          GMC Doctor Lookup
        </h2>
        <div className="flex items-end gap-3 mb-4">
          <div className="flex-1">
            <label className="block text-xs text-muted-foreground mb-1">
              Demo Doctor
            </label>
            <select
              value={selectedName}
              onChange={(e) => setSelectedName(Number(e.target.value))}
              className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground"
            >
              {DEMO_NAMES.map((n, i) => (
                <option key={i} value={i}>
                  {n.givenName} {n.surname}
                </option>
              ))}
            </select>
          </div>
          <button
            onClick={lookupGMC}
            disabled={gmcLoading}
            className="rounded-lg bg-muted px-4 py-2 text-xs font-medium text-foreground hover:bg-muted/80 transition-colors disabled:opacity-50"
          >
            {gmcLoading ? "Looking up..." : "Lookup"}
          </button>
        </div>

        {gmcLoading && (
          <div className="space-y-2">
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-3 w-full" />
          </div>
        )}

        {gmcResults && gmcResults.length > 0 && (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted-foreground">
                  <th className="pb-2 pr-4">GMC Ref</th>
                  <th className="pb-2 pr-4">Name</th>
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

        {gmcError && (
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            {gmcError}
          </div>
        )}
        {gmcResults && gmcResults.length === 0 && (
          <div className="text-sm text-muted-foreground">No records found.</div>
        )}
      </Card>
    </div>
  );
}
