# TLH Chainlink Functions and Automation Runbook

- Document Owner: TLH Chainlink Operations Lead (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Chainlink Ops | Initial runbook baseline |
| v1.0 | 2026-02-16 | TLH Chainlink Ops | Added operations, alerting, and incident checklist |

## Jobs and Triggers Catalog
Current repository jobs (node-centric):
1. `chainlink-node/jobs/deco-verification-job.toml` (bridge-triggered verification).
2. `chainlink-node/jobs/deco-verification-cron.toml` (scheduled verification).
3. Example job templates in `chainlink-node/jobs/*.toml`.

Primary trigger types:
1. Manual trigger via Chainlink UI.
2. Cron trigger by schedule.
3. HTTP/webhook trigger where configured.

## Secrets and Config Management
Configuration sources:
1. Chainlink node config and secrets templates.
2. Environment files for prover API, adapter, and frontend.
3. Contracts env for deployment and fork testing.

Policy:
1. Do not commit real secrets.
2. Use `.env.example` templates and secured secret stores.
3. Enforce gitleaks in pre-commit and CI.

Required controls:
1. Key rotation record updates after any secret exposure event.
2. Principle of least privilege for API keys and chain accounts.
3. Restricted public frontend provider keys.

## Schedule and Automation Policy
Automation policy:
1. Schedule frequency based on credential refresh requirements.
2. Avoid overlapping high-cost jobs.
3. Maintain deterministic retry windows for failed runs.

Operational constraints:
1. Job schedules must not exceed provider rate limits.
2. Chain submission jobs must include fail-fast validation.
3. Attestation refresh jobs must be idempotent when possible.

## Alerting, Monitoring, and SLOs
Monitoring targets:
1. Chainlink node health and job run failures.
2. Prover API and external adapter health endpoints.
3. On-chain transaction success/failure rates.
4. Queue backlog and retry exhaustion.

Proposed SLOs:
1. Job success rate >= 99% over rolling 7 days.
2. Critical job recovery time < 60 minutes.
3. Zero unreviewed critical failures in production window.

Alert levels:
1. P1: repeated failure of critical attestation pipeline.
2. P2: degraded throughput or elevated retry rate.
3. P3: non-critical warnings or transient provider issues.

## Incident Response Playbook
Incident sequence:
1. Detect and classify incident severity (P1/P2/P3).
2. Freeze non-essential job schedules if P1.
3. Collect logs from Chainlink node, adapter, and prover API.
4. Validate RPC/provider status and key validity.
5. Execute remediation (config fix, service restart, fallback route).
6. Re-run validation job and confirm recovery.
7. Record incident summary and preventive action.

Post-incident requirements:
1. Root cause analysis document.
2. Corrective action owner and due date.
3. Runbook update if process gaps were identified.

## Run Verification Checklist
Pre-run:
1. Required services are running and healthy.
2. Correct environment variables and secrets are loaded.
3. Wallet/key has sufficient balance and permissions.

During run:
1. Job triggered successfully.
2. Prover/adapter calls return expected outputs.
3. On-chain transaction hash captured.

Post-run:
1. Verify tx status and events.
2. Confirm data state in target contracts.
3. Archive evidence for QA and handover annex.

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________

