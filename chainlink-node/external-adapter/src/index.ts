/**
 * DECO External Adapter for Chainlink
 *
 * This adapter:
 * 1. Receives requests from Chainlink job (with optional clinician DID)
 * 2. Calls prover-api to verify DECO attestation
 * 3. Builds ADR-002 predicateData and signs chain-bound digests
 * 4. Calls submitAttestation() on Sepolia AttestationVerifier (shared anchor)
 * 5. Calls submitAttestation() on Private Chain TrustAttestationVerifier (trust)
 * 6. Returns both txHashes + attestationId to Chainlink / frontend
 */

import express from "express"
import {
  createWalletClient,
  createPublicClient,
  http,
  keccak256,
  encodeAbiParameters,
  toHex,
  concat,
  defineChain,
} from "viem"
import { privateKeyToAccount } from "viem/accounts"
import { sepolia } from "viem/chains"
import dotenv from "dotenv"

dotenv.config()

const PORT = process.env.EA_PORT || 8788
const PROVER_API_URL = process.env.PROVER_API_URL || "http://localhost:8787"
const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}`
const SEPOLIA_RPC = process.env.SEPOLIA_RPC_URL
const PRIVATE_CHAIN_RPC = process.env.PRIVATE_CHAIN_RPC_URL || "http://localhost:8545"

if (!SEPOLIA_RPC) {
  console.error("ERROR: SEPOLIA_RPC_URL environment variable is required")
  process.exit(1)
}

if (!PRIVATE_KEY) {
  console.error("ERROR: PRIVATE_KEY environment variable is required")
  process.exit(1)
}

// --- Private trust chain definition ---
const privateChain = defineChain({
  id: 100100,
  name: "TLH Private Chain",
  nativeCurrency: { name: "ETH", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: [PRIVATE_CHAIN_RPC] },
  },
})

// --- Contract addresses ---
const ATTESTATION_VERIFIER = "0xce863e465f21df87ad9f0a2af838fac1750f08d2" as `0x${string}` // Sepolia
const TRUST_ATTESTATION_VERIFIER = "0x68B1D87F95878fE05B998F19b66F4baba5De1aed" as `0x${string}` // Private chain

// --- ABI for submitAttestation ---
const SUBMIT_ATTESTATION_ABI = [
  {
    type: "function",
    name: "submitAttestation",
    inputs: [
      { name: "attestationId", type: "bytes32" },
      { name: "subjectDID", type: "bytes32" },
      { name: "predicateData", type: "bytes" },
      { name: "signature", type: "bytes" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const

const DOMAIN = "TLH_ATTESTATION_V1"

// --- Security middleware ---
const EA_API_KEY = process.env.EA_API_KEY || ""
const ALLOWED_ORIGINS = (process.env.CORS_ORIGINS || "http://localhost:3000").split(",")

const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_WINDOW = 60_000
const RATE_LIMIT_MAX = 10

function rateLimitMiddleware(req: express.Request, res: express.Response, next: express.NextFunction) {
  const ip = req.ip || req.socket.remoteAddress || "unknown"
  const now = Date.now()
  const timestamps = (rateLimitMap.get(ip) || []).filter(t => now - t < RATE_LIMIT_WINDOW)
  if (timestamps.length >= RATE_LIMIT_MAX) {
    return res.status(429).json({ error: "Too many requests" })
  }
  timestamps.push(now)
  rateLimitMap.set(ip, timestamps)
  next()
}

function authMiddleware(req: express.Request, res: express.Response, next: express.NextFunction) {
  if (EA_API_KEY && req.headers["x-api-key"] !== EA_API_KEY) {
    return res.status(401).json({ error: "Unauthorized" })
  }
  next()
}

const app = express()
app.use((_req, res, next) => {
  const origin = _req.headers.origin
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    res.header("Access-Control-Allow-Origin", origin)
  }
  res.header("Access-Control-Allow-Headers", "Content-Type, X-API-Key")
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  if (_req.method === "OPTIONS") return res.sendStatus(204)
  next()
})
app.use(express.json())

// Create wallet + public clients
const account = privateKeyToAccount(PRIVATE_KEY)

// Sepolia clients
const sepoliaWallet = createWalletClient({
  account,
  chain: sepolia,
  transport: http(SEPOLIA_RPC),
})

// Private chain clients
const privateWallet = createWalletClient({
  account,
  chain: privateChain,
  transport: http(PRIVATE_CHAIN_RPC),
})
const privatePublic = createPublicClient({
  chain: privateChain,
  transport: http(PRIVATE_CHAIN_RPC),
})

interface DecoVerifyResponse {
  result: "PASS" | "FAIL"
  reason: string
  proofId?: string
  verificationType?: string
  completedAt?: string
  timestamp: string
}

interface ChainlinkRequest {
  id: string | number
  data: {
    endpoint?: string
    clinicianDID?: string
    [key: string]: unknown
  }
}

interface ChainlinkResponse {
  jobRunID: string | number
  statusCode: number
  data?: {
    result: string
    txHash: string
    privateTxHash?: string
    proofId: string
    attestationId: string
    verificationResult: string
  }
  error?: string
}

/**
 * Build ADR-002 predicateData:
 *   predicateData[0] = 0x01 (PASS) or 0x00 (FAIL)
 *   predicateData[1:] = abi.encode(predicateType, result, checkedAt, expiresAt, vcType, contentHash, extraData)
 */
function buildPredicateData(result: boolean, proofId: string): `0x${string}` {
  const predicateType = keccak256(toHex("GMC_REGISTERED"))
  const vcType = keccak256(toHex("GMC_REGISTRATION"))
  const contentHash = keccak256(toHex(`deco-proof-${proofId}`))
  const checkedAt = BigInt(Math.floor(Date.now() / 1000))
  const expiresAt = 0n // non-expiring

  const abiPayload = encodeAbiParameters(
    [
      { type: "bytes32" },  // predicateType
      { type: "bool" },     // result
      { type: "uint256" },  // checkedAt
      { type: "uint256" },  // expiresAt
      { type: "bytes32" },  // vcType
      { type: "bytes32" },  // contentHash
      { type: "bytes" },    // extraData
    ],
    [predicateType, result, checkedAt, expiresAt, vcType, contentHash, "0x"]
  )

  const resultByte = result ? "0x01" : "0x00"
  return concat([resultByte as `0x${string}`, abiPayload])
}

/**
 * Build chain-bound digest per ADR-002 §D and sign it.
 * The digest is specific to each chain + contract pair.
 */
async function signAttestation(
  chainId: number,
  contractAddress: `0x${string}`,
  attestationId: `0x${string}`,
  subjectDID: `0x${string}`,
  predicateData: `0x${string}`
): Promise<`0x${string}`> {
  // M-12: Use abi.encode (matching on-chain BaseAttestationVerifier) to prevent hash collision
  const encoded = encodeAbiParameters(
    [
      { type: "string" },
      { type: "uint256" },
      { type: "address" },
      { type: "bytes32" },
      { type: "bytes32" },
      { type: "bytes32" },
    ],
    [DOMAIN, BigInt(chainId), contractAddress, attestationId, subjectDID, keccak256(predicateData)]
  )
  const digest = keccak256(encoded)

  // signMessage applies EIP-191 prefix which matches Solidity's toEthSignedMessageHash()
  const signature = await account.signMessage({ message: { raw: digest as `0x${string}` } })
  return signature
}

/**
 * POST / — Main adapter endpoint
 *
 * Submits attestations to BOTH chains:
 *   1. Sepolia AttestationVerifier (shared anchor — DID + VCHash)
 *   2. Private Chain TrustAttestationVerifier (trust — credential write)
 */
app.post("/", rateLimitMiddleware, authMiddleware, async (req, res) => {
  const request = req.body as ChainlinkRequest
  const jobRunID = request.id || "1"

  console.log(`[EA] Received request: jobRunID=${jobRunID}`)

  try {
    // Step 1: Call prover-api to verify DECO attestation for the specific doctor
    const surname = request.data?.surname as string | undefined
    const givenName = request.data?.givenName as string | undefined

    let verifyUrl = `${PROVER_API_URL}/deco/verify`
    if (surname && givenName) {
      const params = new URLSearchParams({ surname, givenName })
      verifyUrl = `${verifyUrl}?${params}`
    }
    console.log(`[EA] Calling prover-api at ${verifyUrl}`)

    const verifyResponse = await fetch(verifyUrl)
    if (!verifyResponse.ok) {
      throw new Error(`Prover API returned ${verifyResponse.status}`)
    }

    const verifyData = (await verifyResponse.json()) as DecoVerifyResponse
    console.log(`[EA] Verification result: ${verifyData.result}`)

    const proofId = verifyData.proofId || "unknown"
    const result = verifyData.result === "PASS"

    // Step 2: Determine subject DID
    const clinicianDID = (request.data?.clinicianDID as string) || "did:tlh:clinician-789"
    const subjectDID = keccak256(toHex(clinicianDID)) as `0x${string}`
    console.log(`[EA] Subject DID: ${clinicianDID} -> ${subjectDID}`)

    // Step 3: Build unique attestation ID (same ID for both chains)
    const attestationId = keccak256(
      toHex(`deco-${proofId}-${Date.now()}`)
    ) as `0x${string}`
    console.log(`[EA] Attestation ID: ${attestationId}`)

    // Step 4: Build ADR-002 predicateData (same for both chains)
    const predicateData = buildPredicateData(result, proofId)
    console.log(`[EA] PredicateData built (${predicateData.length} chars)`)

    // Step 5a: Sign + submit to Sepolia (shared anchor)
    const sepoliaSignature = await signAttestation(
      sepolia.id, ATTESTATION_VERIFIER, attestationId, subjectDID, predicateData
    )
    console.log(`[EA] Sepolia signature: ${sepoliaSignature.slice(0, 20)}...`)

    console.log(`[EA] Submitting to Sepolia AttestationVerifier (${ATTESTATION_VERIFIER})`)
    const sepoliaTxHash = await sepoliaWallet.writeContract({
      address: ATTESTATION_VERIFIER,
      abi: SUBMIT_ATTESTATION_ABI,
      functionName: "submitAttestation",
      args: [attestationId, subjectDID, predicateData, sepoliaSignature],
    })
    console.log(`[EA] Sepolia tx: ${sepoliaTxHash}`)

    // Step 5b: Sign + submit to Private Chain (trust)
    let privateTxHash: string | undefined
    try {
      const privateSignature = await signAttestation(
        privateChain.id, TRUST_ATTESTATION_VERIFIER, attestationId, subjectDID, predicateData
      )
      console.log(`[EA] Private chain signature: ${privateSignature.slice(0, 20)}...`)

      console.log(`[EA] Submitting to Private Chain TrustAttestationVerifier (${TRUST_ATTESTATION_VERIFIER})`)
      const rawTxHash = await privateWallet.writeContract({
        address: TRUST_ATTESTATION_VERIFIER,
        abi: SUBMIT_ATTESTATION_ABI,
        functionName: "submitAttestation",
        args: [attestationId, subjectDID, predicateData, privateSignature],
      })
      privateTxHash = rawTxHash
      console.log(`[EA] Private chain tx: ${privateTxHash}`)
    } catch (privateErr) {
      console.warn(`[EA] Private chain submission failed (non-fatal):`, privateErr instanceof Error ? privateErr.message : privateErr)
    }

    // Step 6: Return success response
    const response: ChainlinkResponse = {
      jobRunID,
      statusCode: 200,
      data: {
        result: sepoliaTxHash,
        txHash: sepoliaTxHash,
        privateTxHash,
        proofId,
        attestationId,
        verificationResult: verifyData.result,
      },
    }

    return res.json(response)
  } catch (error) {
    console.error(`[EA] Error:`, error instanceof Error ? error.message.slice(0, 200) : "Unknown error")

    const response: ChainlinkResponse = {
      jobRunID,
      statusCode: 500,
      error: "Pipeline processing failed",
    }

    return res.status(500).json(response)
  }
})

/**
 * Health check endpoint
 */
app.get("/health", async (_req, res) => {
  let privateChainOk = false
  try {
    const chainId = await privatePublic.getChainId()
    privateChainOk = chainId === 100100
  } catch { /* private chain may be down */ }

  res.json({
    status: "ok",
    address: account.address,
    chains: {
      sepolia: { contract: ATTESTATION_VERIFIER },
      privateChain: { contract: TRUST_ATTESTATION_VERIFIER, connected: privateChainOk },
    },
  })
})

app.listen(PORT, () => {
  console.log(`DECO External Adapter running on http://localhost:${PORT}`)
  console.log(`Wallet address: ${account.address}`)
  console.log(`Prover API URL: ${PROVER_API_URL}`)
  console.log(`Sepolia AttestationVerifier: ${ATTESTATION_VERIFIER}`)
  console.log(`Private Chain TrustAttestationVerifier: ${TRUST_ATTESTATION_VERIFIER}`)
  console.log(`Private Chain RPC: ${PRIVATE_CHAIN_RPC}`)
})
