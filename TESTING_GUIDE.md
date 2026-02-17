# TLH Frontend + Backend Testing Guide

## 1. Prerequisites
1. Node.js 20+ and npm installed.
2. Foundry installed (for contracts-related checks).
3. Sepolia RPC configured where needed.

## 2. Install Dependencies
Run once per project folder:

```powershell
cd c:\tlh\frontend
npm install

cd c:\tlh\prover-api
npm install

cd c:\tlh\chainlink-node\external-adapter
npm install
```

## 3. Frontend Testing
### 3.1 Static checks
```powershell
cd c:\tlh\frontend
npm run lint
npm run build
```
Expected: both commands succeed; build prints routes like `/`, `/verify`, `/did`, `/credentials`.

### 3.2 Local run + manual smoke test
```powershell
cd c:\tlh\frontend
npm run dev -- --port 3001
```
Open:
1. `http://localhost:3001/`
2. `http://localhost:3001/verify`
3. `http://localhost:3001/did`
4. `http://localhost:3001/credentials`

Check:
1. Pages load without console/runtime errors.
2. Wallet/RPC interactions do not fail immediately.
3. Forms show validation errors for bad input.

## 4. Prover API (Backend) Testing
### 4.1 Type/build checks
```powershell
cd c:\tlh\prover-api
npm run test
npm run build
```

### 4.2 Start server
```powershell
cd c:\tlh\prover-api
npm run dev
```
Server default: `http://localhost:8787`

### 4.3 Endpoint smoke tests (new terminal)
```powershell
Invoke-WebRequest http://localhost:8787/health
Invoke-WebRequest http://localhost:8787/deco/verify
```
Expected:
1. `/health` returns 200.
2. `/deco/verify` returns JSON with `result` (`PASS` or `FAIL`) and `timestamp`.

## 5. External Adapter Testing
### 5.1 Configure env
Create/update `c:\tlh\chainlink-node\external-adapter\.env`:

```env
EA_PORT=8788
PROVER_API_URL=http://localhost:8787
SEPOLIA_RPC_URL=YOUR_RPC_URL
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

### 5.2 Type/build checks
```powershell
cd c:\tlh\chainlink-node\external-adapter
npm run test
npm run build
```

### 5.3 Start adapter
```powershell
cd c:\tlh\chainlink-node\external-adapter
npm run dev
```
Server default: `http://localhost:8788`

### 5.4 Adapter smoke tests (new terminal)
```powershell
Invoke-WebRequest http://localhost:8788/health

$body = @{
  id = "manual-1"
  data = @{}
} | ConvertTo-Json

Invoke-WebRequest http://localhost:8788/ -Method POST -ContentType "application/json" -Body $body
```
Expected:
1. `/health` returns status and wallet address.
2. POST `/` returns `result` and `txHash` when prover-api is up and env keys are valid.

## 6. End-to-End Flow (Frontend + Backend)
Run in parallel:
1. `prover-api` (`npm run dev`) on `8787`
2. `external-adapter` (`npm run dev`) on `8788`
3. `frontend` (`npm run dev -- --port 3001`) on `3001`

Then:
1. Trigger verify flow from frontend.
2. Confirm logs appear in prover-api and external-adapter terminals.
3. Confirm tx hash is returned by adapter and shown/usable in UI or logs.

## 7. Troubleshooting
1. `tsc not recognized`: run `npm install` in that folder.
2. Adapter startup fails: check `PRIVATE_KEY` and `SEPOLIA_RPC_URL`.
3. Frontend chain errors: ensure `.env.local` uses a working Sepolia RPC.
4. Prover `/deco/verify` FAIL: verify attestation files exist in expected repo paths.
