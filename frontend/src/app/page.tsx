"use client";

import { useContractHealth } from "@/hooks/use-contract-health";
import { useBlockNumber } from "wagmi";
import { CONTRACTS, PRIVATE_CHAIN_CONTRACTS, CCIP_CONTRACTS, CHAINLINK_JOBS } from "@/lib/contracts";
import { privateChain } from "@/lib/wagmi";
import {
  formatAddress,
  etherscanAddressUrl,
} from "@/lib/utils";
import { useEffect, useState } from "react";
import { fetchProverHealth, fetchEAHealth } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

function StatusDot({ ok }: { ok: boolean | undefined }) {
  return (
    <span
      className={`inline-block h-2.5 w-2.5 rounded-full ${
        ok === undefined ? "bg-muted-foreground animate-pulse" : ok ? "bg-success" : "bg-danger"
      }`}
    />
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
  const content = (
    <span className="font-mono text-xs text-muted-foreground hover:text-accent transition-colors break-all">
      {formatAddress(address)}
    </span>
  );

  return (
    <Card>
      <div className="flex items-center justify-between mb-1">
        <h3 className="text-sm font-semibold text-foreground">{name}</h3>
        <StatusDot ok={responsive} />
      </div>
      <div className="text-[10px] text-muted-foreground mb-2">{chainLabel}</div>
      {explorerUrl ? (
        <a href={explorerUrl} target="_blank" rel="noopener noreferrer">
          {content}
        </a>
      ) : (
        content
      )}
    </Card>
  );
}

export default function DashboardPage() {
  const { sepoliaContracts, privateContracts, isLoading } = useContractHealth();
  const { data: sepoliaBlock } = useBlockNumber({ watch: true });
  const { data: privateBlock } = useBlockNumber({ chainId: privateChain.id, watch: true });
  const [proverOk, setProverOk] = useState<boolean | undefined>(undefined);
  const [eaOk, setEaOk] = useState<boolean | undefined>(undefined);

  useEffect(() => {
    fetchProverHealth().then(setProverOk);
    fetchEAHealth().then(setEaOk);
    const interval = setInterval(() => {
      fetchProverHealth().then(setProverOk);
      fetchEAHealth().then(setEaOk);
    }, 15000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Dashboard</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Trust Layer Health — dual-chain system status
        </p>
      </div>

      {/* System status */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-4">
          System Status
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="flex items-center gap-3">
            <StatusDot ok={sepoliaBlock !== undefined} />
            <div>
              <div className="text-sm text-foreground">Sepolia RPC</div>
              <div className="text-xs text-muted-foreground">
                {sepoliaBlock ? `Block #${sepoliaBlock.toString()}` : "Connecting..."}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <StatusDot ok={privateBlock !== undefined} />
            <div>
              <div className="text-sm text-foreground">Private Chain</div>
              <div className="text-xs text-muted-foreground">
                {privateBlock ? `Block #${privateBlock.toString()}` : "Connecting..."}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <StatusDot ok={proverOk} />
            <div>
              <div className="text-sm text-foreground">Prover API</div>
              <div className="text-xs text-muted-foreground">
                {proverOk === undefined ? "Checking..." : proverOk ? "Port 8787" : "Offline"}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <StatusDot ok={eaOk} />
            <div>
              <div className="text-sm text-foreground">External Adapter</div>
              <div className="text-xs text-muted-foreground">
                {eaOk === undefined ? "Checking..." : eaOk ? "Port 8788" : "Offline"}
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
          Jobs defined in <code className="text-accent">chainlink-node/jobs/</code>
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
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Admin</dt>
              <dd className="font-mono text-xs text-foreground">
                {formatAddress(PRIVATE_CHAIN_CONTRACTS.admin)}
              </dd>
            </div>
          </dl>
        </Card>
      </div>

      {/* Architecture */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-3">
          Architecture
        </h2>
        <div className="font-mono text-xs text-muted-foreground space-y-1 leading-relaxed">
          <div>Prover API (DECO Verify)</div>
          <div className="text-accent">{"  |"}</div>
          <div>External Adapter (Dual-Chain Tx Submit)</div>
          <div className="text-accent">{"  / \\"}</div>
          <div className="grid grid-cols-2 gap-4 mt-1">
            <div>
              <div className="text-foreground font-semibold mb-1">
                Sepolia (Shared Anchor)
              </div>
              <div>DIDRegistry</div>
              <div>VCHashAnchors</div>
              <div>AttestationVerifier</div>
              <div className="text-accent mt-1">CCIP Receiver</div>
            </div>
            <div>
              <div className="text-foreground font-semibold mb-1">
                Private Chain (Trust)
              </div>
              <div>CredentialRegistry</div>
              <div>TrustAttestationVerifier</div>
              <div className="text-accent mt-1">CCIP Sender</div>
            </div>
          </div>
          <div className="text-center text-accent mt-2">{"<── CCIP Bridge ──>"}</div>
          <div className="mt-3 pt-3 border-t border-border">
            <div className="text-foreground font-semibold mb-1">
              Chainlink Automation
            </div>
            <div>Webhook Job → On-demand verification</div>
            <div>Cron Job → Scheduled re-verification</div>
          </div>
        </div>
      </Card>
    </div>
  );
}
