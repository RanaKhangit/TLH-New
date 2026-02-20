"use client";

import { CONTRACTS, PRIVATE_CHAIN_CONTRACTS, CCIP_CONTRACTS, CHAINLINK_JOBS } from "@/lib/contracts";
import {
  formatAddress,
  etherscanAddressUrl,
} from "@/lib/utils";
import { useEffect, useState, useRef } from "react";
import { fetchProverHealth, fetchEAHealth, fetchSepoliaHealth, fetchContractsHealth, fetchPrivateChainHealth, type HealthResult, type SepoliaHealthResult, type ContractsHealthResponse, type PrivateChainHealthResult } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";

function StatusDot({ ok }: { ok: boolean | undefined }) {
  if (ok === undefined) {
    return (
      <span
        role="status"
        aria-label="Checking"
        className="inline-block h-2.5 w-2.5 rounded-full bg-muted-foreground animate-pulse"
      />
    );
  }
  if (ok) {
    return (
      <span
        role="status"
        aria-label="Online"
        className="inline-block h-2.5 w-2.5 rounded-full bg-success"
      />
    );
  }
  // Diamond shape for error — distinct from circle for colorblind users
  return (
    <span
      role="status"
      aria-label="Offline"
      className="inline-block h-2.5 w-2.5 rotate-45 bg-danger"
    />
  );
}

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);

  async function handleCopy() {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      toast.success("Address copied to clipboard");
      setTimeout(() => setCopied(false), 1500);
    } catch {
      toast.error("Failed to copy to clipboard");
    }
  }

  return (
    <button
      onClick={handleCopy}
      aria-label="Copy full address"
      title={copied ? "Copied!" : "Copy full address"}
      className="text-muted-foreground hover:text-foreground transition-colors shrink-0"
    >
      {copied ? (
        <span className="text-success text-xs">&#10003;</span>
      ) : (
        <svg className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} aria-hidden="true">
          <path strokeLinecap="round" strokeLinejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
        </svg>
      )}
    </button>
  );
}

function ContractCard({
  name,
  address,
  responsive,
  chainLabel,
  explorerUrl,
}: {
  name: string;
  address: string;
  responsive: boolean;
  chainLabel: string;
  explorerUrl?: string;
}) {
  return (
    <Card>
      <div className="flex items-center justify-between mb-1">
        <h3 className="text-sm font-semibold text-foreground">{name}</h3>
        <StatusDot ok={responsive} />
      </div>
      <div className="text-[10px] text-muted-foreground mb-2">{chainLabel}</div>
      <div className="flex items-center gap-2">
        {explorerUrl ? (
          <a
            href={explorerUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="font-mono text-xs text-muted-foreground hover:text-accent transition-colors break-all"
          >
            {formatAddress(address)}
          </a>
        ) : (
          <span className="font-mono text-xs text-muted-foreground break-all">
            {formatAddress(address)}
          </span>
        )}
        <CopyButton text={address} />
      </div>
    </Card>
  );
}

export default function DashboardPage() {
  const [sepoliaHealth, setSepoliaHealth] = useState<SepoliaHealthResult | undefined>(undefined);
  const [privateChainHealth, setPrivateChainHealth] = useState<PrivateChainHealthResult | undefined>(undefined);
  const [contractsHealth, setContractsHealth] = useState<ContractsHealthResponse | undefined>(undefined);
  const [proverHealth, setProverHealth] = useState<HealthResult | undefined>(undefined);
  const [eaHealth, setEaHealth] = useState<HealthResult | undefined>(undefined);
  const [lastPolled, setLastPolled] = useState<Date | null>(null);
  const prevSepolia = useRef<boolean | undefined>(undefined);
  const prevPrivate = useRef<boolean | undefined>(undefined);
  const prevProver = useRef<boolean | undefined>(undefined);
  const prevEa = useRef<boolean | undefined>(undefined);

  // Build sepoliaContracts from server-side health check
  const sepoliaContracts = contractsHealth?.contracts.map(c => ({
    name: c.name,
    address: c.address,
    responsive: c.responsive,
    chain: "sepolia" as const,
  })) ?? [
    { name: "DIDRegistry", address: CONTRACTS.DIDRegistry.proxy, responsive: false, chain: "sepolia" as const },
    { name: "AttestationVerifier", address: CONTRACTS.AttestationVerifier.proxy, responsive: false, chain: "sepolia" as const },
    { name: "VCHashAnchors", address: CONTRACTS.VCHashAnchors.proxy, responsive: false, chain: "sepolia" as const },
  ];

  // Private contracts use server-side health check
  const privateContracts = [
    { name: "CredentialRegistry", address: PRIVATE_CHAIN_CONTRACTS.CredentialRegistry.proxy, responsive: privateChainHealth?.ok ?? false, chain: "private" as const },
    { name: "TrustAttestationVerifier", address: PRIVATE_CHAIN_CONTRACTS.TrustAttestationVerifier.proxy, responsive: privateChainHealth?.ok ?? false, chain: "private" as const },
  ];

  const isLoading = contractsHealth === undefined;

  useEffect(() => {
    function poll() {
      fetchSepoliaHealth().then((r) => {
        setSepoliaHealth(r);
        if (prevSepolia.current !== undefined && prevSepolia.current !== r.ok) {
          toast[r.ok ? "success" : "error"](`Sepolia RPC ${r.ok ? "back online" : "went offline"}`);
        }
        prevSepolia.current = r.ok;
      });
      fetchPrivateChainHealth().then((r) => {
        setPrivateChainHealth(r);
        if (prevPrivate.current !== undefined && prevPrivate.current !== r.ok) {
          toast[r.ok ? "success" : "error"](`Private Chain ${r.ok ? "back online" : "went offline"}`);
        }
        prevPrivate.current = r.ok;
      });
      fetchContractsHealth().then(setContractsHealth);
      fetchProverHealth().then((r) => {
        setProverHealth(r);
        if (prevProver.current !== undefined && prevProver.current !== r.ok) {
          toast[r.ok ? "success" : "error"](`Prover API ${r.ok ? "back online" : "went offline"}`);
        }
        prevProver.current = r.ok;
      });
      fetchEAHealth().then((r) => {
        setEaHealth(r);
        if (prevEa.current !== undefined && prevEa.current !== r.ok) {
          toast[r.ok ? "success" : "error"](`External Adapter ${r.ok ? "back online" : "went offline"}`);
        }
        prevEa.current = r.ok;
      });
      setLastPolled(new Date());
    }
    poll();
    const interval = setInterval(poll, 15000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Dashboard</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Trust Layer Health — dual-chain system status
          </p>
        </div>
        {(() => {
          const checks = [sepoliaHealth?.ok, privateChainHealth?.ok, proverHealth?.ok, eaHealth?.ok];
          const ready = checks.filter(Boolean).length;
          if (ready === 4) return <Badge variant="success">{ready}/4 All Systems Operational</Badge>;
          if (ready >= 2) return <Badge variant="warning">{ready}/4 Degraded</Badge>;
          return <Badge variant="danger">{ready}/4 Critical</Badge>;
        })()}
      </div>

      {/* System status */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-foreground">
            System Status
          </h2>
          {lastPolled && (
            <span className="text-[10px] text-muted-foreground">
              Polled {lastPolled.toLocaleTimeString()} — every 15s
            </span>
          )}
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="flex items-center gap-3">
            <StatusDot ok={sepoliaHealth?.ok} />
            <div>
              <div className="text-sm text-foreground">Sepolia RPC</div>
              <div className="text-xs text-muted-foreground">
                {sepoliaHealth === undefined ? "Checking..." : sepoliaHealth.ok ? `Block #${sepoliaHealth.blockNumber}` : "Offline"}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <StatusDot ok={privateChainHealth?.ok} />
            <div>
              <div className="text-sm text-foreground">Private Chain</div>
              <div className="text-xs text-muted-foreground">
                {privateChainHealth === undefined ? "Checking..." : privateChainHealth.ok ? `Block #${privateChainHealth.blockNumber}` : "Offline"}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <StatusDot ok={proverHealth?.ok} />
            <div>
              <div className="text-sm text-foreground">Prover API</div>
              <div className="text-xs text-muted-foreground">
                {proverHealth === undefined ? "Checking..." : proverHealth.ok ? `Healthy — ${proverHealth.latencyMs}ms` : "Offline"}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <StatusDot ok={eaHealth?.ok} />
            <div>
              <div className="text-sm text-foreground">External Adapter</div>
              <div className="text-xs text-muted-foreground">
                {eaHealth === undefined ? "Checking..." : eaHealth.ok ? `Healthy — ${eaHealth.latencyMs}ms` : "Offline"}
              </div>
            </div>
          </div>
        </div>
      </Card>

      {/* Sepolia contracts */}
      <div>
        <h2 className="text-sm font-semibold text-foreground mb-3">
          Sepolia — Shared Anchor Contracts
        </h2>
        {isLoading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {[1, 2, 3].map((i) => (
              <Card key={i}>
                <Skeleton className="h-4 w-32 mb-3" />
                <Skeleton className="h-3 w-48" />
              </Card>
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {sepoliaContracts.map((c) => (
              <ContractCard
                key={c.name}
                name={c.name}
                address={c.address}
                responsive={c.responsive}
                chainLabel="Sepolia (11155111)"
                explorerUrl={etherscanAddressUrl(c.address)}
              />
            ))}
          </div>
        )}
      </div>

      {/* Private chain contracts */}
      <div>
        <h2 className="text-sm font-semibold text-foreground mb-3">
          Private Chain — Trust Contracts
        </h2>
        {isLoading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {[1, 2].map((i) => (
              <Card key={i}>
                <Skeleton className="h-4 w-32 mb-3" />
                <Skeleton className="h-3 w-48" />
              </Card>
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {privateContracts.map((c) => (
              <ContractCard
                key={c.name}
                name={c.name}
                address={c.address}
                responsive={c.responsive}
                chainLabel="Private Chain (100100)"
              />
            ))}
          </div>
        )}
      </div>

      {/* CCIP Cross-Chain Contracts */}
      <div>
        <h2 className="text-sm font-semibold text-foreground mb-3">
          CCIP — Cross-Chain Interoperability
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <ContractCard
            name="TLHCCIPReceiver"
            address={CCIP_CONTRACTS.TLHCCIPReceiver.proxy}
            responsive={true}
            chainLabel="Sepolia (11155111)"
            explorerUrl={etherscanAddressUrl(CCIP_CONTRACTS.TLHCCIPReceiver.proxy)}
          />
          <ContractCard
            name="TLHCCIPSender"
            address={CCIP_CONTRACTS.TLHCCIPSender.proxy}
            responsive={true}
            chainLabel="Sepolia (11155111)"
            explorerUrl={etherscanAddressUrl(CCIP_CONTRACTS.TLHCCIPSender.proxy)}
          />
        </div>
      </div>

      {/* Chainlink Automation */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-4">
          Chainlink Automation Jobs
        </h2>
        <div className="space-y-3">
          {CHAINLINK_JOBS.map((job) => (
            <div
              key={job.file}
              className="flex items-center justify-between p-3 rounded-lg bg-muted"
            >
              <div>
                <div className="text-sm font-medium text-foreground">
                  {job.name}
                </div>
                <div className="text-xs text-muted-foreground">
                  {job.description}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-mono text-muted-foreground">
                  {job.type}
                </span>
                <span className="h-2 w-2 rounded-full bg-success" />
              </div>
            </div>
          ))}
        </div>
        <p className="text-xs text-muted-foreground mt-3">
          Jobs defined in <code className="font-mono text-foreground bg-muted px-1 py-0.5 rounded text-[11px]">chainlink-node/jobs/</code>
        </p>
      </Card>

      {/* Network info */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-3">
            Sepolia Network
          </h2>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Chain ID</dt>
              <dd className="font-mono text-foreground">
                {CONTRACTS.chainId}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Network</dt>
              <dd className="text-foreground capitalize">
                {CONTRACTS.network}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Admin</dt>
              <dd>
                <a
                  href={etherscanAddressUrl(CONTRACTS.admin)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-mono text-accent hover:underline"
                >
                  {formatAddress(CONTRACTS.admin)}
                </a>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Proxy Pattern</dt>
              <dd className="text-foreground">UUPS (ERC-1967)</dd>
            </div>
          </dl>
        </Card>

        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-3">
            Private Chain Network
          </h2>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Chain ID</dt>
              <dd className="font-mono text-foreground">
                {PRIVATE_CHAIN_CONTRACTS.chainId}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Network</dt>
              <dd className="text-foreground">
                {PRIVATE_CHAIN_CONTRACTS.network}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Consensus</dt>
              <dd className="text-foreground">IBFT 2.0 (4 validators)</dd>
            </div>
            <div className="flex justify-between items-center">
              <dt className="text-muted-foreground">Admin</dt>
              <dd className="flex items-center gap-1.5">
                <span className="font-mono text-xs text-foreground">
                  {formatAddress(PRIVATE_CHAIN_CONTRACTS.admin)}
                </span>
                <CopyButton text={PRIVATE_CHAIN_CONTRACTS.admin} />
              </dd>
            </div>
          </dl>
        </Card>
      </div>

      {/* Architecture */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-4">
          Architecture
        </h2>
        <div className="space-y-4">
          {/* Top services */}
          <div className="flex flex-col items-center gap-2">
            <div className="rounded-lg bg-accent/10 border border-accent/30 px-4 py-2 text-xs font-medium text-accent">
              Prover API (DECO Verify)
            </div>
            <svg className="h-4 w-4 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
            </svg>
            <div className="rounded-lg bg-muted border border-border px-4 py-2 text-xs font-medium text-foreground">
              External Adapter (Dual-Chain Submit)
            </div>
          </div>

          {/* Fork to chains */}
          <div className="flex justify-center">
            <svg className="h-6 w-24 text-accent" viewBox="0 0 96 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <path d="M48 0 L48 8 L24 20 M48 8 L72 20" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>

          {/* Dual chain columns */}
          <div className="grid grid-cols-2 gap-4">
            <div className="rounded-lg bg-muted/50 border border-border p-3">
              <div className="text-xs font-semibold text-foreground mb-2 flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-accent" />
                Sepolia (Shared Anchor)
              </div>
              <div className="space-y-1 text-xs text-muted-foreground">
                <div className="flex items-center gap-2">
                  <span className="h-1.5 w-1.5 rounded-full bg-success" />
                  DIDRegistry
                </div>
                <div className="flex items-center gap-2">
                  <span className="h-1.5 w-1.5 rounded-full bg-success" />
                  VCHashAnchors
                </div>
                <div className="flex items-center gap-2">
                  <span className="h-1.5 w-1.5 rounded-full bg-success" />
                  AttestationVerifier
                </div>
                <div className="flex items-center gap-2 mt-2 text-accent">
                  <span className="h-1.5 w-1.5 rounded-full bg-accent" />
                  CCIP Receiver
                </div>
              </div>
            </div>
            <div className="rounded-lg bg-muted/50 border border-border p-3">
              <div className="text-xs font-semibold text-foreground mb-2 flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-muted-foreground" />
                Private Chain (Trust)
              </div>
              <div className="space-y-1 text-xs text-muted-foreground">
                <div className="flex items-center gap-2">
                  <span className="h-1.5 w-1.5 rounded-full bg-success" />
                  CredentialRegistry
                </div>
                <div className="flex items-center gap-2">
                  <span className="h-1.5 w-1.5 rounded-full bg-success" />
                  TrustAttestationVerifier
                </div>
                <div className="flex items-center gap-2 mt-2 text-accent">
                  <span className="h-1.5 w-1.5 rounded-full bg-accent" />
                  CCIP Sender
                </div>
              </div>
            </div>
          </div>

          {/* CCIP Bridge */}
          <div className="flex items-center justify-center gap-2 py-1">
            <div className="h-px flex-1 bg-accent/30" />
            <span className="text-xs font-medium text-accent px-2">CCIP Bridge</span>
            <div className="h-px flex-1 bg-accent/30" />
          </div>

          {/* Chainlink Automation */}
          <div className="rounded-lg bg-muted/30 border border-border p-3">
            <div className="text-xs font-semibold text-foreground mb-2">Chainlink Automation</div>
            <div className="grid grid-cols-2 gap-2 text-xs text-muted-foreground">
              <div className="flex items-center gap-2">
                <span className="text-accent">Webhook</span>
                <span>On-demand verification</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-accent">Cron</span>
                <span>Scheduled re-verification</span>
              </div>
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}
