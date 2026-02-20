"use client";

import { useEffect } from "react";
import Link from "next/link";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

const DOCS = [
  {
    title: "CTO Review",
    description: "Technical architecture overview, data flows, and deployment details",
    path: "CTO-REVIEW.md",
    badge: "Start Here",
  },
  {
    title: "Demo Guide",
    description: "Quick start guide for running the demo environment",
    path: "DEMO-README.md",
    badge: "Getting Started",
  },
  {
    title: "Testing Guide",
    description: "How to run the test suites (173 tests)",
    path: "TESTING_GUIDE.md",
  },
  {
    title: "Architecture",
    description: "Contract architecture and design decisions",
    path: "contracts/docs/ARCHITECTURE.md",
  },
  {
    title: "ADR-001: UUPS Upgradeability",
    description: "Why we chose UUPS over Transparent Proxy",
    path: "contracts/docs/adr/ADR-001-uups-upgradeability.md",
  },
  {
    title: "ADR-002: Attestation ID Design",
    description: "How attestation IDs are generated and verified",
    path: "contracts/docs/adr/ADR-002-attestation-id-design.md",
  },
  {
    title: "ADR-003: Hash Anchoring Strategy",
    description: "VC hash anchoring approach and trade-offs",
    path: "contracts/docs/adr/ADR-003-hash-anchoring-strategy.md",
  },
  {
    title: "ADR-004: CCIP Integration",
    description: "Cross-chain credential sharing via Chainlink CCIP",
    path: "contracts/docs/adr/ADR-004-ccip-integration.md",
  },
  {
    title: "Event Schema",
    description: "Smart contract events and their parameters",
    path: "contracts/docs/event-schema.md",
  },
];

const DELIVERY_DOCS = [
  {
    title: "01 - MVP Scope Definition",
    description: "In-scope features and acceptance criteria",
    path: "contracts/docs/delivery/01-mvp-scope-definition.md",
  },
  {
    title: "02 - Roadmap & Sprint Plan",
    description: "Milestones, sprints, and dependencies",
    path: "contracts/docs/delivery/02-roadmap-and-sprint-plan.md",
  },
  {
    title: "03 - Formal QA Report",
    description: "Test results and coverage analysis",
    path: "contracts/docs/delivery/03-formal-qa-report.md",
  },
  {
    title: "04 - Security Assessment",
    description: "Security controls and compliance posture",
    path: "contracts/docs/delivery/04-security-and-compliance-assessment.md",
  },
  {
    title: "05 - Deployment & Handover",
    description: "Deployment procedures and operational handover",
    path: "contracts/docs/delivery/05-deployment-and-handover-pack.md",
  },
  {
    title: "06 - Private Chain Architecture",
    description: "Polygon Edge IBFT 2.0 setup and operations",
    path: "contracts/docs/delivery/06-private-chain-architecture-and-ops.md",
  },
  {
    title: "07 - CCIP Integration Spec",
    description: "Cross-chain messaging implementation",
    path: "contracts/docs/delivery/07-ccip-integration-spec.md",
  },
  {
    title: "08 - Chainlink Automation Runbook",
    description: "Automation jobs and monitoring",
    path: "contracts/docs/delivery/08-chainlink-functions-automation-runbook.md",
  },
];

export default function DocsPage() {
  useEffect(() => {
    document.title = "Documentation | Trust Layer Health";
  }, []);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Documentation</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Technical documentation, architecture decisions, and delivery artifacts
        </p>
      </div>

      {/* Quick Links */}
      <div className="flex gap-4 flex-wrap">
        <a
          href="https://github.com/RanaKhangit/TLH-New"
          target="_blank"
          rel="noopener noreferrer"
          className="rounded-lg bg-muted px-4 py-2 text-sm font-medium text-foreground hover:bg-muted/80 transition-colors"
        >
          GitHub Repository
        </a>
        <a
          href="https://sepolia.etherscan.io/address/0xce863e465f21df87ad9f0a2af838fac1750f08d2"
          target="_blank"
          rel="noopener noreferrer"
          className="rounded-lg bg-muted px-4 py-2 text-sm font-medium text-foreground hover:bg-muted/80 transition-colors"
        >
          AttestationVerifier (Etherscan)
        </a>
        <Link
          href="/verify"
          className="rounded-lg bg-accent px-4 py-2 text-sm font-bold text-accent-foreground hover:bg-accent/80 transition-colors"
        >
          Try the Demo
        </Link>
      </div>

      {/* Architecture & Design */}
      <section>
        <h2 className="text-lg font-semibold text-foreground mb-4">Architecture & Design</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {DOCS.map((doc) => (
            <a
              key={doc.path}
              href={`https://github.com/RanaKhangit/TLH-New/blob/main/${doc.path}`}
              target="_blank"
              rel="noopener noreferrer"
              className="block group"
            >
              <Card className="hover:border-accent/40 transition-colors h-full">
                <div className="flex items-start justify-between gap-2 mb-2">
                  <h3 className="font-medium text-foreground text-sm group-hover:text-accent transition-colors">{doc.title}</h3>
                  {doc.badge && (
                    <Badge variant="success" className="shrink-0">
                      {doc.badge}
                    </Badge>
                  )}
                </div>
                <p className="text-xs text-muted-foreground mb-3">{doc.description}</p>
                <div className="flex items-center gap-2 text-xs text-muted-foreground/70">
                  <svg className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                  <code className="font-mono truncate">{doc.path}</code>
                </div>
              </Card>
            </a>
          ))}
        </div>
      </section>

      {/* Delivery Documents */}
      <section>
        <h2 className="text-lg font-semibold text-foreground mb-4">Delivery Documents</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {DELIVERY_DOCS.map((doc) => (
            <a
              key={doc.path}
              href={`https://github.com/RanaKhangit/TLH-New/blob/main/${doc.path}`}
              target="_blank"
              rel="noopener noreferrer"
              className="block group"
            >
              <Card className="hover:border-accent/40 transition-colors h-full">
                <h3 className="font-medium text-foreground text-sm mb-1 group-hover:text-accent transition-colors">{doc.title}</h3>
                <p className="text-xs text-muted-foreground mb-3">{doc.description}</p>
                <div className="flex items-center gap-2 text-xs text-muted-foreground/70">
                  <svg className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                  <code className="font-mono truncate">{doc.path}</code>
                </div>
              </Card>
            </a>
          ))}
        </div>
      </section>

      {/* Contract Addresses */}
      <section>
        <h2 className="text-lg font-semibold text-foreground mb-4">Contract Addresses (Sepolia)</h2>
        <Card>
          <div className="space-y-2 text-sm font-mono">
            <div className="flex justify-between">
              <span className="text-muted-foreground">DIDRegistry</span>
              <a
                href="https://sepolia.etherscan.io/address/0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent hover:underline"
              >
                0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a
              </a>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">VCHashAnchors</span>
              <a
                href="https://sepolia.etherscan.io/address/0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent hover:underline"
              >
                0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68
              </a>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">CredentialRegistry</span>
              <a
                href="https://sepolia.etherscan.io/address/0xae4b71776fab8e431cee4874ad3a2a97588d89fb"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent hover:underline"
              >
                0xae4b71776fab8e431cee4874ad3a2a97588d89fb
              </a>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">AttestationVerifier</span>
              <a
                href="https://sepolia.etherscan.io/address/0xce863e465f21df87ad9f0a2af838fac1750f08d2"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent hover:underline"
              >
                0xce863e465f21df87ad9f0a2af838fac1750f08d2
              </a>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">TrustAttestationVerifier</span>
              <a
                href="https://sepolia.etherscan.io/address/0x2ad7540b14585ebfb3c86604d1927b40e2efa5db"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent hover:underline"
              >
                0x2ad7540b14585ebfb3c86604d1927b40e2efa5db
              </a>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">TLHCCIPReceiver</span>
              <a
                href="https://sepolia.etherscan.io/address/0x234Aec51d3977bA5174B068d2Daf15e5367C0bF0"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent hover:underline"
              >
                0x234Aec51d3977bA5174B068d2Daf15e5367C0bF0
              </a>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">TLHCCIPSender</span>
              <a
                href="https://sepolia.etherscan.io/address/0xB8238cA59c7479e16d888A86A533A3113886A260"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent hover:underline"
              >
                0xB8238cA59c7479e16d888A86A533A3113886A260
              </a>
            </div>
          </div>
        </Card>
      </section>

      {/* Test Results */}
      <section>
        <h2 className="text-lg font-semibold text-foreground mb-4">Test Results</h2>
        <Card>
          <div className="flex items-center gap-4 mb-4">
            <Badge variant="success">173 Passed</Badge>
            <Badge variant="muted">0 Failed</Badge>
            <Badge variant="muted">14 Suites</Badge>
          </div>
          <p className="text-sm text-muted-foreground">
            Run <code className="bg-muted px-1 rounded">forge test --summary</code> in the contracts directory to verify.
          </p>
        </Card>
      </section>
    </div>
  );
}
