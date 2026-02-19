"use client";

import { useState, useEffect, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useResolveDID } from "@/hooks/use-did-registry";
import { useGetAttestation } from "@/hooks/use-attestation-by-did";
import {
  formatTimestamp,
  formatTimestampRelative,
  formatAddress,
  formatBytes32,
  toBytes32,
  isValidBytes32,
  etherscanAddressUrl,
} from "@/lib/utils";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

const DEMO_DIDS = [
  { label: "did:tlh:clinician-789", value: "did:tlh:clinician-789" },
  { label: "did:tlh:patient-123", value: "did:tlh:patient-123" },
];

export default function DIDExplorerPage() {
  return (
    <Suspense fallback={<DIDExplorerSkeleton />}>
      <DIDExplorerContent />
    </Suspense>
  );
}

function DIDExplorerSkeleton() {
  return (
    <div className="space-y-8">
      <div>
        <Skeleton className="h-8 w-48 mb-2" />
        <Skeleton className="h-4 w-72" />
      </div>
      <Card>
        <Skeleton className="h-10 w-full" />
      </Card>
    </div>
  );
}

function DIDExplorerContent() {
  const searchParams = useSearchParams();

  const [input, setInput] = useState("");
  const [hashMode, setHashMode] = useState(true);
  const [queriedDID, setQueriedDID] = useState<`0x${string}` | undefined>();
  const [inputError, setInputError] = useState<string | null>(null);
  const [highlightedAttestation, setHighlightedAttestation] = useState<`0x${string}` | undefined>();

  const { data, isLoading, error } = useResolveDID(queriedDID);

  // Accept DID and attestationId from URL (e.g. from Verify page link)
  useEffect(() => {
    const did = searchParams.get("did");
    const attestationId = searchParams.get("attestationId");

    if (did) {
      setInput(did);
      setHashMode(true);
      setQueriedDID(toBytes32(did));
    }
    if (attestationId) {
      setHighlightedAttestation(attestationId as `0x${string}`);
    }
  }, [searchParams]);

  function handleResolve() {
    setInputError(null);
    if (!input.trim()) return;
    if (hashMode) {
      setQueriedDID(toBytes32(input.trim()));
    } else {
      if (isValidBytes32(input.trim())) {
        setQueriedDID(input.trim() as `0x${string}`);
      } else {
        setInputError("Invalid format — must be 0x followed by 64 hex characters.");
      }
    }
  }

  const notFound = error?.message?.includes("revert") || error?.message?.includes("DIDNotFound");

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-foreground">DID Explorer</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Look up a Decentralized Identifier on the DIDRegistry
        </p>
      </div>

      <Card>
        <div className="space-y-4">
          <div className="flex items-center gap-3">
            <label className="flex items-center gap-2 text-xs text-muted-foreground">
              <input
                type="checkbox"
                checked={hashMode}
                onChange={(e) => setHashMode(e.target.checked)}
                className="rounded"
              />
              Hash string to bytes32 (keccak256)
            </label>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <input
                type="text"
                value={input}
                onChange={(e) => { setInput(e.target.value); setInputError(null); }}
                placeholder={
                  hashMode
                    ? 'e.g. did:tlh:clinician-789'
                    : "0x... (bytes32 hex)"
                }
                className={`w-full rounded-lg border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground ${inputError ? "border-danger" : "border-border"}`}
                onKeyDown={(e) => e.key === "Enter" && handleResolve()}
              />
            </div>
            <button
              onClick={handleResolve}
              disabled={!input.trim() || isLoading}
              className="rounded-lg bg-accent px-4 py-2 text-xs font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50"
            >
              {isLoading ? "Resolving..." : "Resolve DID"}
            </button>
          </div>
          {inputError && (
            <p className="text-xs text-danger">{inputError}</p>
          )}

          <div className="flex gap-2">
            {DEMO_DIDS.map((d) => (
              <button
                key={d.value}
                onClick={() => {
                  setInput(d.value);
                  setHashMode(true);
                }}
                className="rounded-md bg-muted px-2 py-1 text-xs text-muted-foreground hover:text-foreground transition-colors"
              >
                {d.label}
              </button>
            ))}
          </div>

          {queriedDID && (
            <div className="text-xs text-muted-foreground font-mono">
              Querying: {queriedDID}
            </div>
          )}
        </div>
      </Card>

      {isLoading && queriedDID && (
        <Card>
          <Skeleton className="h-4 w-24 mb-4" />
          <div className="space-y-3">
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-1/2" />
          </div>
        </Card>
      )}

      {notFound && queriedDID && (
        <Card>
          <div className="text-center py-4">
            <Badge variant="muted">DID Not Found</Badge>
            <p className="text-sm text-muted-foreground mt-2">
              This DID is not registered in the DIDRegistry contract.
            </p>
          </div>
        </Card>
      )}

      {data && !notFound && (
        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-4">
            DID Record
          </h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Status</dt>
              <dd>
                <Badge variant={data[1] ? "success" : "danger"}>
                  {data[1] ? "Active" : "Deactivated"}
                </Badge>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Controller</dt>
              <dd>
                <a
                  href={etherscanAddressUrl(data[0])}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-mono text-accent hover:underline"
                >
                  {formatAddress(data[0])}
                </a>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Registered At</dt>
              <dd className="text-foreground">
                {formatTimestamp(data[2])}{" "}
                <span className="text-muted-foreground text-xs">
                  ({formatTimestampRelative(data[2])})
                </span>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Updated At</dt>
              <dd className="text-foreground">
                {formatTimestamp(data[3])}{" "}
                <span className="text-muted-foreground text-xs">
                  ({formatTimestampRelative(data[3])})
                </span>
              </dd>
            </div>
          </dl>
        </Card>
      )}

      {data && !notFound && queriedDID && (
        <AttestationsForDID
          subjectDID={queriedDID}
          highlightedAttestation={highlightedAttestation}
        />
      )}
    </div>
  );
}

function AttestationsForDID({
  subjectDID,
  highlightedAttestation,
}: {
  subjectDID: `0x${string}`;
  highlightedAttestation?: `0x${string}`;
}) {
  const attestation = useGetAttestation(highlightedAttestation);

  // Suppress unused-var lint — subjectDID reserved for future event-log queries
  void subjectDID;

  if (!highlightedAttestation) {
    return (
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-2">
          Attestations
        </h2>
        <p className="text-xs text-muted-foreground">
          No attestation selected. Run a verification from the Verify Credential
          page to see attestation details here.
        </p>
      </Card>
    );
  }

  return (
    <Card>
      <h2 className="text-sm font-semibold text-foreground mb-4">
        Attestation Details
      </h2>

      {attestation.isLoading && (
        <div className="space-y-2">
          <Skeleton className="h-3 w-48" />
          <Skeleton className="h-3 w-full" />
        </div>
      )}

      {attestation.error && (
        <Badge variant="danger">Failed to load attestation</Badge>
      )}

      {attestation.data && (
        <dl className="space-y-3 text-sm">
          <div className="flex justify-between items-center">
            <dt className="text-muted-foreground">Status</dt>
            <dd>
              <Badge variant={attestation.data[0] ? "success" : "muted"}>
                {attestation.data[0] ? "On-Chain" : "Not Found"}
              </Badge>
            </dd>
          </div>
          <div>
            <dt className="text-muted-foreground mb-1">Attestation ID</dt>
            <dd className="font-mono text-xs text-foreground bg-muted p-2 rounded break-all">
              {highlightedAttestation}
            </dd>
          </div>
          <div className="flex justify-between items-center">
            <dt className="text-muted-foreground">Result</dt>
            <dd>
              <Badge variant={attestation.data[3] ? "success" : "danger"}>
                {attestation.data[3] ? "PASS" : "FAIL"}
              </Badge>
            </dd>
          </div>
          <div>
            <dt className="text-muted-foreground mb-1">Subject DID (bytes32)</dt>
            <dd className="font-mono text-xs text-foreground bg-muted p-2 rounded break-all">
              {formatBytes32(attestation.data[1])}
            </dd>
          </div>
        </dl>
      )}
    </Card>
  );
}
