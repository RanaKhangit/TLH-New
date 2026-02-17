"use client";

import { useContractHealth } from "@/hooks/use-contract-health";
import { useBlockNumber } from "wagmi";
import { CONTRACTS } from "@/lib/contracts";
import {
  formatAddress,
  etherscanAddressUrl,
} from "@/lib/utils";
import { useEffect, useState } from "react";
import { fetchProverHealth, fetchEAHealth } from "@/lib/api";

function StatusDot({ ok }: { ok: boolean | undefined }) {
  return (
    <span
      className={`inline-block h-2.5 w-2.5 rounded-full ${
        ok === undefined ? "bg-muted-foreground animate-pulse" : ok ? "bg-success" : "bg-danger"
      }`}
    />
  );
}

function Card({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`rounded-xl border border-border bg-card p-5 ${className}`}
    >
      {children}
    </div>
  );
}

function ContractCard({
  name,
  address,
  responsive,
}: {
  name: string;
  address: string;
  responsive: boolean;
}) {
  return (
    <Card>
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-foreground">{name}</h3>
        <StatusDot ok={responsive} />
      </div>
      <a
        href={etherscanAddressUrl(address)}
        target="_blank"
        rel="noopener noreferrer"
        className="font-mono text-xs text-muted-foreground hover:text-accent transition-colors break-all"
      >
        {formatAddress(address)}
      </a>
    </Card>
  );
}

export default function DashboardPage() {
  const { contracts, isLoading } = useContractHealth();
  const { data: blockNumber } = useBlockNumber({ watch: true });
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
          Trust Layer Health system status on Sepolia
        </p>
      </div>

      {/* System status */}
      <Card>
        <h2 className="text-sm font-semibold text-foreground mb-4">
          System Status
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div className="flex items-center gap-3">
            <StatusDot ok={blockNumber !== undefined} />
            <div>
              <div className="text-sm text-foreground">Sepolia RPC</div>
              <div className="text-xs text-muted-foreground">
                {blockNumber ? `Block #${blockNumber.toString()}` : "Connecting..."}
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

      {/* Contract cards */}
      <div>
        <h2 className="text-sm font-semibold text-foreground mb-3">
          Deployed Contracts
        </h2>
        {isLoading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {[1, 2, 3, 4, 5].map((i) => (
              <Card key={i}>
                <div className="h-12 bg-muted rounded animate-pulse" />
              </Card>
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {contracts.map((c) => (
              <ContractCard
                key={c.name}
                name={c.name}
                address={c.address}
                responsive={c.responsive}
              />
            ))}
          </div>
        )}
      </div>

      {/* Network info */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <Card>
          <h2 className="text-sm font-semibold text-foreground mb-3">
            Network Info
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
            Architecture
          </h2>
          <div className="font-mono text-xs text-muted-foreground space-y-1 leading-relaxed">
            <div>Prover API (DECO Verify)</div>
            <div className="text-accent">{"  |"}</div>
            <div>External Adapter (Tx Submit)</div>
            <div className="text-accent">{"  |"}</div>
            <div>Chainlink Node (Orchestrator)</div>
            <div className="text-accent">{"  |"}</div>
            <div className="text-foreground font-semibold">
              Sepolia Contracts
            </div>
            <div className="mt-2 grid grid-cols-2 gap-1 text-muted-foreground">
              <span>Shared: DIDRegistry</span>
              <span>Trust: CredentialRegistry</span>
              <span>Shared: VCHashAnchors</span>
              <span>Trust: TrustAttVerifier</span>
              <span>Shared: AttVerifier</span>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
