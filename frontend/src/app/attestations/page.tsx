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

function Card({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`rounded-xl border border-border bg-card p-5 ${className}`}>
      {children}
    </div>
  );
}

function Badge({
  variant,
  children,
}: {
  variant: "success" | "danger" | "muted";
  children: React.ReactNode;
}) {
  const colors = {
    success: "bg-success/10 text-success border-success/20",
    danger: "bg-danger/10 text-danger border-danger/20",
    muted: "bg-muted text-muted-foreground border-border",
  };
  return (
    <span
      className={`inline-flex items-center rounded-md border px-2.5 py-0.5 text-xs font-medium ${colors[variant]}`}
    >
      {children}
    </span>
  );
}

export default function AttestationsPage() {
  const [input, setInput] = useState("");
  const [verifier, setVerifier] = useState<"shared" | "trust">("shared");
  const [queriedId, setQueriedId] = useState<`0x${string}` | undefined>();

  const sharedResult = useVerifyAttestation(
    verifier === "shared" ? queriedId : undefined
  );
  const trustResult = useTrustVerifyAttestation(
    verifier === "trust" ? queriedId : undefined
  );

  const result = verifier === "shared" ? sharedResult : trustResult;
  const { data, isLoading, error } = result;

  function handleLookup() {
    if (!input.trim()) return;
    if (isValidBytes32(input.trim())) {
      setQueriedId(input.trim() as `0x${string}`);
    }
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
              onClick={() => setVerifier("shared")}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                verifier === "shared"
                  ? "bg-accent/10 text-accent"
                  : "bg-muted text-muted-foreground hover:text-foreground"
              }`}
            >
              Shared Anchor Verifier
            </button>
            <button
              onClick={() => setVerifier("trust")}
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
              onChange={(e) => setInput(e.target.value)}
              placeholder="Attestation ID (0x... bytes32)"
              className="flex-1 rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground"
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
        </div>
      </Card>

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
