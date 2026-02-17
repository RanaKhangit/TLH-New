# TLH Frontend Demo

## Purpose
Next.js dashboard for demo and operator workflows across:
1. Shared attestation verification
2. DID lookups
3. VC hash anchors
4. Trust credential reads

## Environment
Create `frontend/.env.local`:

```env
NEXT_PUBLIC_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
NEXT_PUBLIC_PROVER_API_URL=http://localhost:8787
NEXT_PUBLIC_EA_URL=http://localhost:8788
```

Notes:
1. `NEXT_PUBLIC_SEPOLIA_RPC_URL` should use a reliable provider (Alchemy/publicnode).
2. Do not commit real keys.

## Run
From `frontend/`:

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Quality Checks
From `frontend/`:

```bash
npm run build
npm run lint
```

## Contract Wiring
Frontend contract addresses are sourced from:
- `frontend/src/lib/contracts.ts`

Network transport is configured in:
- `frontend/src/lib/wagmi.ts`
