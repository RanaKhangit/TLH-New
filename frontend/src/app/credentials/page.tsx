"use client";

import { useState } from "react";
import { useGetCredential, useIsCredentialValid } from "@/hooks/use-credential-registry";
import { useGetAnchor } from "@/hooks/use-vc-anchors";
import {
  formatTimestamp,
  formatTimestampRelative,
  formatBytes32,
  toBytes32,
  isValidBytes32,
  credentialStatusLabel,
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
  variant: "success" | "danger" | "muted" | "warning";
  children: React.ReactNode;
}) {
  const colors = {
    success: "bg-success/10 text-success border-success/20",
    danger: "bg-danger/10 text-danger border-danger/20",
    warning: "bg-warning/10 text-warning border-warning/20",
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

function statusBadgeVariant(status: number): "success" | "danger" | "warning" {
  if (status === 0) return "success";
  if (status === 2) return "danger";
  return "warning";
}

export default function CredentialsPage() {
  const [didInput, setDidInput] = useState("");
  const [predInput, setPredInput] = useState("GMC_REGISTERED");
  const [hashMode, setHashMode] = useState(true);
  const [queriedDID, setQueriedDID] = useState<`0x${string}` | undefined>();
  const [queriedPred, setQueriedPred] = useState<`0x${string}` | undefined>();

  // Anchor lookup
  const [anchorVcType, setAnchorVcType] = useState("GMC_LICENSE");
  const [anchorDID, setAnchorDID] = useState<`0x${string}` | undefined>();
  const [anchorType, setAnchorType] = useState<`0x${string}` | undefined>();

  const { data: credential, isLoading: credLoading, error: credError } =
    useGetCredential(queriedDID, queriedPred);
  const { data: isValid, isLoading: validLoading } =
    useIsCredentialValid(queriedDID, queriedPred);
  const { data: anchor, isLoading: anchorLoading, error: anchorError } =
    useGetAnchor(anchorDID, anchorType);

  function handleQuery() {
    if (!didInput.trim() || !predInput.trim()) return;
    const did = hashMode ? toBytes32(didInput.trim()) : (didInput.trim() as `0x${string}`);
    const pred = hashMode ? toBytes32(predInput.trim()) : (predInput.trim() as `0x${string}`);
    setQueriedDID(did);
    setQueriedPred(pred);
  }

  function handleAnchorQuery() {
    if (!didInput.trim() || !anchorVcType.trim()) return;
    const did = hashMode ? toBytes32(didInput.trim()) : (didInput.trim() as `0x${string}`);
    const vt = hashMode ? toBytes32(anchorVcType.trim()) : (anchorVcType.trim() as `0x${string}`);
    setAnchorDID(did);
    setAnchorType(vt);
  }

  const notFound =
    credError?.message?.includes("revert") ||
    credError?.message?.includes("CredentialNotFound");

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-foreground">
          Credential Explorer
        </h1>
        <p className="text-sm text-muted-foreground mt-1">
          Query credential and VC anchor state on-chain
        </p>
      </div>

      {/* Credential lookup */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-4">
          Credential Lookup
        </h2>
        <div className="space-y-3">
          <label className="flex items-center gap-2 text-xs text-muted-foreground">
            <input
              type="checkbox"
              checked={hashMode}
              onChange={(e) => setHashMode(e.target.checked)}
              className="rounded"
            />
            Hash strings to bytes32
          </label>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs text-muted-foreground mb-1">
                Subject DID
              </label>
              <input
                type="text"
                value={didInput}
                onChange={(e) => setDidInput(e.target.value)}
                placeholder="did:tlh:clinician-789"
                className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground"
              />
            </div>
            <div>
              <label className="block text-xs text-muted-foreground mb-1">
                Predicate Type
              </label>
              <input
                type="text"
                value={predInput}
                onChange={(e) => setPredInput(e.target.value)}
                placeholder="GMC_REGISTERED"
                className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground"
              />
            </div>
          </div>
          <button
            onClick={handleQuery}
            disabled={credLoading || !didInput.trim()}
            className="rounded-lg bg-accent px-4 py-2 text-xs font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50"
          >
            {credLoading ? "Loading..." : "Get Credential"}
          </button>
        </div>
      </Card>

      {notFound && queriedDID && (
        <Card>
          <div className="text-center py-4">
            <Badge variant="muted">Credential Not Found</Badge>
            <p className="text-sm text-muted-foreground mt-2">
              No credential record exists for this DID + predicate pair.
            </p>
          </div>
        </Card>
      )}

      {credential && !notFound && (
        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-4">
            Credential Record
          </h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Status</dt>
              <dd>
                <Badge variant={statusBadgeVariant(credential.status)}>
                  {credentialStatusLabel(credential.status)}
                </Badge>
              </dd>
            </div>
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Valid</dt>
              <dd>
                <Badge variant={credential.valid ? "success" : "danger"}>
                  {credential.valid ? "Yes" : "No"}
                </Badge>
              </dd>
            </div>
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Live Validity Check</dt>
              <dd>
                {validLoading ? (
                  <span className="text-muted-foreground text-xs">
                    Checking...
                  </span>
                ) : (
                  <Badge variant={isValid ? "success" : "danger"}>
                    {isValid ? "Currently Valid" : "Currently Invalid"}
                  </Badge>
                )}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Subject DID</dt>
              <dd className="font-mono text-xs text-foreground">
                {formatBytes32(credential.subjectDID)}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Predicate Type</dt>
              <dd className="font-mono text-xs text-foreground">
                {formatBytes32(credential.predicateType)}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Checked At</dt>
              <dd className="text-foreground">
                {formatTimestamp(credential.checkedAt)}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Expires At</dt>
              <dd className="text-foreground">
                {credential.expiresAt === 0n
                  ? "Never"
                  : `${formatTimestamp(credential.expiresAt)} (${formatTimestampRelative(credential.expiresAt)})`}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Attestation ID</dt>
              <dd className="font-mono text-xs text-foreground">
                {formatBytes32(credential.attestationId)}
              </dd>
            </div>
          </dl>
        </Card>
      )}

      {/* Anchor lookup */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-4">
          VC Hash Anchor Lookup
        </h2>
        <div className="space-y-3">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs text-muted-foreground mb-1">
                Subject DID (same as above)
              </label>
              <input
                type="text"
                value={didInput}
                disabled
                className="w-full rounded-lg border border-border bg-muted/50 px-3 py-2 text-sm text-muted-foreground font-mono"
              />
            </div>
            <div>
              <label className="block text-xs text-muted-foreground mb-1">
                VC Type
              </label>
              <input
                type="text"
                value={anchorVcType}
                onChange={(e) => setAnchorVcType(e.target.value)}
                placeholder="GMC_LICENSE"
                className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground"
              />
            </div>
          </div>
          <button
            onClick={handleAnchorQuery}
            disabled={anchorLoading || !didInput.trim()}
            className="rounded-lg bg-muted px-4 py-2 text-xs font-medium text-foreground hover:bg-muted/80 transition-colors disabled:opacity-50"
          >
            {anchorLoading ? "Loading..." : "Get Anchor"}
          </button>
        </div>
      </Card>

      {anchorError && anchorDID && (
        <Card>
          <div className="text-center py-4">
            <Badge variant="muted">Anchor Not Found</Badge>
          </div>
        </Card>
      )}

      {anchor && !anchorError && (
        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-4">
            Anchor Record
          </h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Content Hash</dt>
              <dd className="font-mono text-xs text-foreground">
                {formatBytes32(anchor[0])}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Anchored At</dt>
              <dd className="text-foreground">
                {formatTimestamp(anchor[1])}
              </dd>
            </div>
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Revoked</dt>
              <dd>
                <Badge variant={anchor[2] ? "danger" : "success"}>
                  {anchor[2] ? "Revoked" : "Active"}
                </Badge>
              </dd>
            </div>
          </dl>
        </Card>
      )}
    </div>
  );
}
