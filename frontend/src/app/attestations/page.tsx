"use client";

import { useState } from "react";
import {
  useVerifyAttestation,
  useTrustVerifyAttestation,
} from "@/hooks/use-attestation-verifier";
import {
  formatTimestamp,
  formatTimestampRelative,
  formatBytes32,
  isValidBytes32,
} from "@/lib/utils";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

export default function AttestationsPage() {
  const [input, setInput] = useState("");
  const [verifier, setVerifier] = useState<"shared" | "trust">("shared");
  const [queriedId, setQueriedId] = useState<`0x${string}` | undefined>();
  const [inputError, setInputError] = useState<string | null>(null);

  const sharedResult = useVerifyAttestation(
    verifier === "shared" ? queriedId : undefined
  );
  const trustResult = useTrustVerifyAttestation(
    verifier === "trust" ? queriedId : undefined
  );

  const result = verifier === "shared" ? sharedResult : trustResult;
  const { data, isLoading, error } = result;

  function handleLookup() {
    setInputError(null);
    if (!input.trim()) return;
    if (isValidBytes32(input.trim())) {
      setQueriedId(input.trim() as `0x${string}`);
    } else {
      setInputError("Invalid format — must be 0x followed by 64 hex characters.");
    }
  }

  function switchVerifier(v: "shared" | "trust") {
    setVerifier(v);
    setQueriedId(undefined);
    setInputError(null);
  }

  const notFound = data && !data[0];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-foreground">
          Attestation Viewer
        </h1>
        <p className="text-sm text-muted-foreground mt-1">
          Look up attestation records stored on-chain
        </p>
      </div>

      <Card>
        <div className="space-y-4">
          <div className="flex gap-3">
            <button
              onClick={() => switchVerifier("shared")}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                verifier === "shared"
                  ? "bg-accent/10 text-accent"
                  : "bg-muted text-muted-foreground hover:text-foreground"
              }`}
            >
              Shared Anchor Verifier
            </button>
            <button
              onClick={() => switchVerifier("trust")}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                verifier === "trust"
                  ? "bg-accent/10 text-accent"
                  : "bg-muted text-muted-foreground hover:text-foreground"
              }`}
            >
              Trust Chain Verifier
            </button>
          </div>

          <div className="flex gap-3">
            <input
              type="text"
              value={input}
              onChange={(e) => { setInput(e.target.value); setInputError(null); }}
              placeholder="Attestation ID (0x... bytes32)"
              className={`flex-1 rounded-lg border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground ${inputError ? "border-danger" : "border-border"}`}
              onKeyDown={(e) => e.key === "Enter" && handleLookup()}
            />
            <button
              onClick={handleLookup}
              disabled={!input.trim() || isLoading}
              className="rounded-lg bg-accent px-4 py-2 text-xs font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50"
            >
              {isLoading ? "Looking up..." : "Look Up"}
            </button>
          </div>
          {inputError && (
            <p className="text-xs text-danger">{inputError}</p>
          )}
        </div>
      </Card>

      {isLoading && queriedId && (
        <Card>
          <Skeleton className="h-4 w-32 mb-4" />
          <div className="space-y-3">
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-1/2" />
          </div>
        </Card>
      )}

      {notFound && queriedId && (
        <Card>
          <div className="text-center py-4">
            <Badge variant="muted">Attestation Not Found</Badge>
            <p className="text-sm text-muted-foreground mt-2">
              No attestation with this ID exists on the{" "}
              {verifier === "shared" ? "Shared Anchor" : "Trust Chain"} verifier.
            </p>
          </div>
        </Card>
      )}

      {data && data[0] && (
        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-4">
            Attestation Record
          </h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Exists</dt>
              <dd>
                <Badge variant="success">Yes</Badge>
              </dd>
            </div>
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Result</dt>
              <dd>
                <Badge variant={data[3] ? "success" : "danger"}>
                  {data[3] ? "PASS (Positive)" : "FAIL (Negative)"}
                </Badge>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Subject DID</dt>
              <dd className="font-mono text-xs text-foreground">
                {formatBytes32(data[1])}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Predicate Hash</dt>
              <dd className="font-mono text-xs text-foreground">
                {formatBytes32(data[2])}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Timestamp</dt>
              <dd className="text-foreground">
                {formatTimestamp(data[4])}{" "}
                <span className="text-muted-foreground text-xs">
                  ({formatTimestampRelative(data[4])})
                </span>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Verifier</dt>
              <dd className="text-foreground capitalize">{verifier}</dd>
            </div>
          </dl>
        </Card>
      )}

      {error && !notFound && (
        <Card>
          <div className="rounded-lg bg-danger/10 border border-danger/20 p-3 text-sm text-danger">
            Error: {error.message?.slice(0, 200)}
          </div>
        </Card>
      )}
    </div>
  );
}
