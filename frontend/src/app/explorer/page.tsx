"use client";

import { useState, useEffect, Suspense } from "react";
import { useSearchParams, useRouter } from "next/navigation";

// DID tab imports
import { useResolveDID } from "@/hooks/use-did-registry";
import { useGetAttestation } from "@/hooks/use-attestation-by-did";

// Credentials tab imports
import { useGetCredential, useIsCredentialValid } from "@/hooks/use-credential-registry";
import { useGetAnchor } from "@/hooks/use-vc-anchors";

// Attestations tab imports
import {
  useVerifyAttestation,
  useTrustVerifyAttestation,
} from "@/hooks/use-attestation-verifier";

import {
  formatTimestamp,
  formatTimestampRelative,
  formatAddress,
  formatBytes32,
  toBytes32,
  isValidBytes32,
  etherscanAddressUrl,
  credentialStatusLabel,
} from "@/lib/utils";
import { Card } from "@/components/ui/card";
import { Badge, type BadgeVariant } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";
import { CONTRACTS, PRIVATE_CHAIN_CONTRACTS, CCIP_CONTRACTS } from "@/lib/contracts";

type Tab = "did" | "credentials" | "attestations";

const TABS: { key: Tab; label: string }[] = [
  { key: "did", label: "DID" },
  { key: "credentials", label: "Credentials" },
  { key: "attestations", label: "Attestations" },
];

export default function ExplorerPage() {
  return (
    <Suspense fallback={<ExplorerSkeleton />}>
      <ExplorerContent />
    </Suspense>
  );
}

function ExplorerSkeleton() {
  return (
    <div className="space-y-8">
      <div>
        <Skeleton className="h-8 w-32 mb-2" />
        <Skeleton className="h-4 w-64" />
      </div>
      <div className="flex gap-4 border-b border-border pb-2">
        <Skeleton className="h-8 w-16" />
        <Skeleton className="h-8 w-24" />
        <Skeleton className="h-8 w-24" />
      </div>
      <Card>
        <Skeleton className="h-10 w-full" />
      </Card>
    </div>
  );
}

function ExplorerContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const initialTab = searchParams.get("tab");
  const [activeTab, setActiveTab] = useState<Tab>(
    initialTab === "credentials" || initialTab === "attestations" ? initialTab : "did"
  );

  useEffect(() => { document.title = "Explorer | Trust Layer Health"; }, []);

  function handleTabChange(tab: Tab) {
    setActiveTab(tab);
    const params = new URLSearchParams(searchParams.toString());
    params.set("tab", tab);
    router.replace(`/explorer?${params.toString()}`, { scroll: false });
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Explorer</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Query on-chain data — DIDs, Credentials, and Attestations
          </p>
        </div>
        <button
          onClick={() => {
            const all = [
              ...Object.entries(CONTRACTS).filter(([, v]) => typeof v === "object" && "proxy" in v).map(([k, v]) => `${k}: ${(v as { proxy: string }).proxy}`),
              ...Object.entries(CCIP_CONTRACTS).map(([k, v]) => `${k}: ${v.proxy}`),
              ...Object.entries(PRIVATE_CHAIN_CONTRACTS).filter(([, v]) => typeof v === "object" && "proxy" in v).map(([k, v]) => `${k}: ${(v as { proxy: string }).proxy}`),
            ].join("\n");
            navigator.clipboard.writeText(all);
            toast.success("All contract addresses copied to clipboard");
          }}
          className="rounded-lg bg-muted px-4 py-2 text-sm font-medium text-foreground hover:bg-muted/80 transition-colors shrink-0"
        >
          Copy All Addresses
        </button>
      </div>

      {/* Tab bar */}
      <div className="flex gap-1 border-b border-border">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => handleTabChange(tab.key)}
            className={`px-4 py-2.5 text-sm font-medium transition-colors border-b-2 -mb-px ${
              activeTab === tab.key
                ? "border-accent text-accent"
                : "border-transparent text-muted-foreground hover:text-foreground"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      {activeTab === "did" && <DIDTab />}
      {activeTab === "credentials" && <CredentialsTab />}
      {activeTab === "attestations" && <AttestationsTab />}
    </div>
  );
}

/* ─── DID Tab ─── */

const DEMO_DIDS = [
  { label: "did:tlh:clinician-789", value: "did:tlh:clinician-789" },
  { label: "did:tlh:patient-123", value: "did:tlh:patient-123" },
];

function useRecentDIDs() {
  const [recent, setRecent] = useState<string[]>([]);
  useEffect(() => {
    try {
      const stored = localStorage.getItem("tlh-recent-dids");
      if (stored) setRecent(JSON.parse(stored));
    } catch { /* ignore */ }
  }, []);
  function add(did: string) {
    setRecent((prev) => {
      const next = [did, ...prev.filter((d) => d !== did)].slice(0, 5);
      localStorage.setItem("tlh-recent-dids", JSON.stringify(next));
      return next;
    });
  }
  return { recent, add };
}

function DIDTab() {
  const searchParams = useSearchParams();
  const initialDid = searchParams.get("did");
  const initialAttestationId = searchParams.get("attestationId");

  const [input, setInput] = useState(initialDid ?? "");
  const [hashMode, setHashMode] = useState(true);
  const [queriedDID, setQueriedDID] = useState<`0x${string}` | undefined>(
    initialDid ? toBytes32(initialDid) : undefined
  );
  const [inputError, setInputError] = useState<string | null>(null);
  const highlightedAttestation = initialAttestationId ? (initialAttestationId as `0x${string}`) : undefined;
  const { recent: recentDIDs, add: addRecentDID } = useRecentDIDs();

  const { data, isLoading, error } = useResolveDID(queriedDID);

  function handleResolve() {
    setInputError(null);
    if (!input.trim()) {
      setInputError("Please enter a DID to resolve.");
      return;
    }
    if (hashMode) {
      setQueriedDID(toBytes32(input.trim()));
      addRecentDID(input.trim());
    } else {
      if (isValidBytes32(input.trim())) {
        setQueriedDID(input.trim() as `0x${string}`);
        addRecentDID(input.trim());
      } else {
        setInputError("Invalid format — must be 0x followed by 64 hex characters.");
      }
    }
  }

  // DID not found: contract may revert OR return zero-value data (controller = 0x0, timestamps = 0)
  const notFound =
    error?.message?.includes("revert") ||
    error?.message?.includes("DIDNotFound") ||
    (data && !isLoading && !error && data[0] === "0x0000000000000000000000000000000000000000" && data[2] === 0n);

  return (
    <div className="space-y-6">
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
              <span title="Converts human-readable strings (like DID identifiers) into the bytes32 format used on-chain via keccak256 hashing">Hash string to bytes32 (keccak256)</span>
            </label>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <input
                type="text"
                value={input}
                onChange={(e) => { setInput(e.target.value); setInputError(null); }}
                placeholder={hashMode ? "e.g. did:tlh:clinician-789" : "0x... (bytes32 hex)"}
                className={`w-full rounded-lg border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground ${inputError ? "border-danger" : "border-border"}`}
                onKeyDown={(e) => e.key === "Enter" && handleResolve()}
              />
            </div>
            <button
              onClick={handleResolve}
              disabled={isLoading}
              className="rounded-lg bg-accent px-4 py-2 text-xs font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50"
            >
              {isLoading ? "Resolving..." : "Resolve DID"}
            </button>
          </div>
          {inputError && <p className="text-xs text-danger">{inputError}</p>}

          <div className="flex gap-2 flex-wrap">
            {DEMO_DIDS.map((d) => (
              <button
                key={d.value}
                onClick={() => { setInput(d.value); setHashMode(true); }}
                className="rounded-md bg-muted px-2 py-1 text-xs text-muted-foreground hover:text-foreground transition-colors"
              >
                {d.label}
              </button>
            ))}
          </div>

          {recentDIDs.length > 0 && (
            <div>
              <div className="text-xs text-muted-foreground mb-1.5">Recent DIDs</div>
              <div className="flex gap-2 flex-wrap">
                {recentDIDs.map((d) => (
                  <button
                    key={d}
                    onClick={() => { setInput(d); setHashMode(d.startsWith("did:") || !d.startsWith("0x")); }}
                    className="rounded-md bg-muted px-2 py-1 text-xs font-mono text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {d.length > 30 ? `${d.slice(0, 14)}...${d.slice(-6)}` : d}
                  </button>
                ))}
              </div>
            </div>
          )}

          {queriedDID && (
            <div className="text-xs text-muted-foreground font-mono">
              Querying: {queriedDID}
            </div>
          )}
        </div>
      </Card>

      {!queriedDID && !isLoading && (
        <div className="text-center py-8 text-muted-foreground">
          <p className="text-sm">Enter a DID above to query the on-chain registry.</p>
          <p className="text-xs mt-1">Try one of the demo DIDs to get started.</p>
        </div>
      )}

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
          <h2 className="text-sm font-semibold text-foreground mb-4">DID Record</h2>
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
  void subjectDID;

  if (!highlightedAttestation) {
    return (
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-2">Attestations</h2>
        <p className="text-xs text-muted-foreground">
          No attestation selected. Run a verification from the Verify Credential page to see attestation details here.
        </p>
      </Card>
    );
  }

  return (
    <Card>
      <h2 className="text-sm font-semibold text-foreground mb-4">Attestation Details</h2>
      {attestation.isLoading && (
        <div className="space-y-2">
          <Skeleton className="h-3 w-48" />
          <Skeleton className="h-3 w-full" />
        </div>
      )}
      {attestation.error && <Badge variant="danger">Failed to load attestation</Badge>}
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

/* ─── Credentials Tab ─── */

function statusBadgeVariant(status: number): BadgeVariant {
  if (status === 0) return "success";
  if (status === 2) return "danger";
  return "warning";
}

function CredentialsTab() {
  const [didInput, setDidInput] = useState("");
  const [predInput, setPredInput] = useState("GMC_REGISTERED");
  const [hashMode, setHashMode] = useState(true);
  const [queriedDID, setQueriedDID] = useState<`0x${string}` | undefined>();
  const [queriedPred, setQueriedPred] = useState<`0x${string}` | undefined>();

  const [anchorVcType, setAnchorVcType] = useState("GMC_LICENSE");
  const [anchorDID, setAnchorDID] = useState<`0x${string}` | undefined>();
  const [anchorType, setAnchorType] = useState<`0x${string}` | undefined>();

  const { data: credential, isLoading: credLoading, error: credError } =
    useGetCredential(queriedDID, queriedPred);
  const { data: isValid, isLoading: validLoading } =
    useIsCredentialValid(queriedDID, queriedPred);
  const { data: anchor, isLoading: anchorLoading, error: anchorError } =
    useGetAnchor(anchorDID, anchorType);

  const [credError2, setCredError2] = useState<string | null>(null);

  function handleQuery() {
    setCredError2(null);
    if (!didInput.trim()) {
      setCredError2("Please enter a Subject DID.");
      return;
    }
    if (!predInput.trim()) {
      setCredError2("Please enter a Predicate Type.");
      return;
    }
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
    <div className="space-y-6">
      {/* Credential lookup */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-2">Credential Lookup</h2>
        <p className="text-xs text-muted-foreground mb-4">
          Reads from CredentialRegistry on Private Chain (100100)
        </p>
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
              <label className="block text-xs text-muted-foreground mb-1">Subject DID</label>
              <input
                type="text"
                value={didInput}
                onChange={(e) => { setDidInput(e.target.value); setCredError2(null); }}
                placeholder="did:tlh:clinician-789"
                className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground"
                onKeyDown={(e) => e.key === "Enter" && handleQuery()}
              />
            </div>
            <div>
              <label className="block text-xs text-muted-foreground mb-1">Predicate Type</label>
              <input
                type="text"
                value={predInput}
                onChange={(e) => setPredInput(e.target.value)}
                placeholder="GMC_REGISTERED"
                className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground"
                onKeyDown={(e) => e.key === "Enter" && handleQuery()}
              />
            </div>
          </div>
          <div className="flex gap-2">
            {DEMO_DIDS.map((d) => (
              <button
                key={d.value}
                onClick={() => { setDidInput(d.value); setHashMode(true); setCredError2(null); }}
                className="rounded-md bg-muted px-2 py-1 text-xs text-muted-foreground hover:text-foreground transition-colors"
              >
                {d.label}
              </button>
            ))}
          </div>
          <button
            onClick={handleQuery}
            disabled={credLoading}
            className="rounded-lg bg-accent px-4 py-2 text-xs font-bold text-accent-foreground hover:bg-accent/80 transition-colors disabled:opacity-50"
          >
            {credLoading ? "Loading..." : "Get Credential"}
          </button>
          {credError2 && <p className="text-xs text-danger">{credError2}</p>}
        </div>
      </Card>

      {!queriedDID && !credLoading && (
        <div className="text-center py-8 text-muted-foreground">
          <p className="text-sm">Enter a Subject DID and Predicate Type to look up credential state.</p>
          <p className="text-xs mt-1">Reads from CredentialRegistry on the Private Chain.</p>
        </div>
      )}

      {credLoading && queriedDID && (
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
          <h2 className="text-sm font-semibold text-foreground mb-4">Credential Record</h2>
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
                  <span className="text-muted-foreground text-xs">Checking...</span>
                ) : (
                  <Badge variant={isValid ? "success" : "danger"}>
                    {isValid ? "Currently Valid" : "Currently Invalid"}
                  </Badge>
                )}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Subject DID</dt>
              <dd className="font-mono text-xs text-foreground">{formatBytes32(credential.subjectDID)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Predicate Type</dt>
              <dd className="font-mono text-xs text-foreground">{formatBytes32(credential.predicateType)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Checked At</dt>
              <dd className="text-foreground">{formatTimestamp(credential.checkedAt)}</dd>
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
              <dd className="font-mono text-xs text-foreground">{formatBytes32(credential.attestationId)}</dd>
            </div>
          </dl>
        </Card>
      )}

      {/* Anchor lookup */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-2">VC Hash Anchor Lookup</h2>
        <p className="text-xs text-muted-foreground mb-4">
          Reads from VCHashAnchors on Sepolia (shared anchor)
        </p>
        <div className="space-y-3">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs text-muted-foreground mb-1">Subject DID (same as above)</label>
              <input
                type="text"
                value={didInput}
                disabled
                placeholder="Fill Subject DID above first"
                className="w-full rounded-lg border border-border bg-muted/50 px-3 py-2 text-sm text-muted-foreground font-mono placeholder:text-muted-foreground/50"
              />
            </div>
            <div>
              <label className="block text-xs text-muted-foreground mb-1">VC Type</label>
              <input
                type="text"
                value={anchorVcType}
                onChange={(e) => setAnchorVcType(e.target.value)}
                placeholder="GMC_LICENSE"
                className="w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-foreground font-mono placeholder:text-muted-foreground"
                onKeyDown={(e) => e.key === "Enter" && handleAnchorQuery()}
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

      {anchorLoading && anchorDID && (
        <Card>
          <Skeleton className="h-4 w-32 mb-4" />
          <div className="space-y-3">
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-3 w-1/2" />
          </div>
        </Card>
      )}

      {anchorError && anchorDID && (
        <Card>
          <div className="text-center py-4">
            <Badge variant="muted">Anchor Not Found</Badge>
          </div>
        </Card>
      )}

      {anchor && !anchorError && (
        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-4">Anchor Record</h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Content Hash</dt>
              <dd className="font-mono text-xs text-foreground">{formatBytes32(anchor[0])}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Anchored At</dt>
              <dd className="text-foreground">{formatTimestamp(anchor[1])}</dd>
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

/* ─── Attestations Tab ─── */

function AttestationsTab() {
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
    if (!input.trim()) {
      setInputError("Please enter an attestation ID (bytes32).");
      return;
    }
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
    <div className="space-y-6">
      <Card>
        <div className="space-y-4">
          <div className="flex gap-3">
            <button
              onClick={() => switchVerifier("shared")}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors border ${
                verifier === "shared"
                  ? "bg-accent/10 text-accent border-accent/40"
                  : "bg-muted text-muted-foreground border-transparent hover:text-foreground"
              }`}
            >
              Shared Anchor (Sepolia)
            </button>
            <button
              onClick={() => switchVerifier("trust")}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors border ${
                verifier === "trust"
                  ? "bg-accent/10 text-accent border-accent/40"
                  : "bg-muted text-muted-foreground border-transparent hover:text-foreground"
              }`}
            >
              Trust Chain (Private 100100)
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
          {inputError && <p className="text-xs text-danger">{inputError}</p>}
        </div>
      </Card>

      {!queriedId && !isLoading && (
        <div className="text-center py-8 text-muted-foreground">
          <p className="text-sm">Enter an attestation ID (bytes32) to look up its on-chain record.</p>
          <p className="text-xs mt-1">
            Switch between Shared Anchor (Sepolia) and Trust Chain (Private) above.
          </p>
        </div>
      )}

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
          <h2 className="text-sm font-semibold text-foreground mb-4">Attestation Record</h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Exists</dt>
              <dd><Badge variant="success">Yes</Badge></dd>
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
              <dd className="font-mono text-xs text-foreground">{formatBytes32(data[1])}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Predicate Hash</dt>
              <dd className="font-mono text-xs text-foreground">{formatBytes32(data[2])}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Timestamp</dt>
              <dd className="text-foreground">
                {formatTimestamp(data[4])}{" "}
                <span className="text-muted-foreground text-xs">({formatTimestampRelative(data[4])})</span>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Verifier</dt>
              <dd className="text-foreground">
                {verifier === "shared" ? "Sepolia (11155111)" : "Private Chain (100100)"}
              </dd>
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
