/**
 * DECO External Adapter for Chainlink
 *
 * This adapter:
 * 1. Receives requests from Chainlink job (with optional clinician DID)
 * 2. Calls prover-api to verify DECO attestation
 * 3. Builds ADR-002 predicateData and signs a chain-bound digest
 * 4. Calls submitAttestation() on the AttestationVerifier contract
 * 5. Returns the txHash + attestationId to Chainlink / frontend
 */

import express from "express"
import {
  createWalletClient,
  createPublicClient,
  http,
  keccak256,
  encodeAbiParameters,
  encodePacked,
  toHex,
  concat,
  hashMessage,
  getContractAddress,
} from "viem"
import { privateKeyToAccount, signMessage } from "viem/accounts"
import { sepolia } from "viem/chains"
import dotenv from "dotenv"

dotenv.config()

const PORT = process.env.EA_PORT || 8788
const PROVER_API_URL = process.env.PROVER_API_URL || "http://localhost:8787"
const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}`
const SEPOLIA_RPC = process.env.SEPOLIA_RPC_URL

if (!SEPOLIA_RPC) {
  console.error("ERROR: SEPOLIA_RPC_URL environment variable is required")
  process.exit(1)
}

if (!PRIVATE_KEY) {
  console.error("ERROR: PRIVATE_KEY environment variable is required")
  process.exit(1)
}

// --- Contract addresses (Sepolia deployment manifest) ---
const ATTESTATION_VERIFIER = "0xce863e465f21df87ad9f0a2af838fac1750f08d2" as `0x${string}`

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
  {
    type: "function",
    name: "addSigner",
    inputs: [{ name: "signer", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "signerWhitelist",
    inputs: [{ name: "", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
] as const

const DOMAIN = "TLH_ATTESTATION_V1"

const app = express()
app.use((_req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*")
  res.header("Access-Control-Allow-Headers", "Content-Type")
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  if (_req.method === "OPTIONS") return res.sendStatus(204)
  next()
})
app.use(express.json())

// Create wallet + public clients
const account = privateKeyToAccount(PRIVATE_KEY)
const walletClient = createWalletClient({
  account,
  chain: sepolia,
  transport: http(SEPOLIA_RPC),
})
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(SEPOLIA_RPC),
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
 * Build chain-bound digest per ADR-002 §D and sign it:
 *   digest = keccak256(DOMAIN + chainId + contractAddress + attestationId + subjectDID + keccak256(predicateData))
 *   ethSignedMessage(digest)
 */
async function signAttestation(
  attestationId: `0x${string}`,
  subjectDID: `0x${string}`,
  predicateData: `0x${string}`
): Promise<`0x${string}`> {
  const packed = encodePacked(
    ["string", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [DOMAIN, BigInt(sepolia.id), ATTESTATION_VERIFIER, attestationId, subjectDID, keccak256(predicateData)]
  )
  const digest = keccak256(packed)

  // signMessage applies EIP-191 prefix ("\x19Ethereum Signed Message:\n32" + digest)
  // which matches Solidity's toEthSignedMessageHash()
  const signature = await account.signMessage({ message: { raw: digest as `0x${string}` } })
  return signature
}

/**
 * POST / — Main adapter endpoint
 *
 * Accepts optional { data: { clinicianDID: "did:tlh:clinician-789" } }
 * If no DID provided, uses a default demo DID.
 */
app.post("/", async (req, res) => {
  const request = req.body as ChainlinkRequest
  const jobRunID = request.id || "1"

  console.log(`[EA] Received request: jobRunID=${jobRunID}`)

  try {
    // Step 1: Call prover-api to verify DECO attestation
    console.log(`[EA] Calling prover-api at ${PROVER_API_URL}/deco/verify`)

    const verifyResponse = await fetch(`${PROVER_API_URL}/deco/verify`)
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

    // Step 3: Build unique attestation ID (includes timestamp to avoid replay)
    const attestationId = keccak256(
      toHex(`deco-${proofId}-${Date.now()}`)
    ) as `0x${string}`
    console.log(`[EA] Attestation ID: ${attestationId}`)

    // Step 4: Build ADR-002 predicateData
    const predicateData = buildPredicateData(result, proofId)
    console.log(`[EA] PredicateData built (${predicateData.length} chars)`)

    // Step 5: Sign the chain-bound digest
    const signature = await signAttestation(attestationId, subjectDID, predicateData)
    console.log(`[EA] Signature: ${signature.slice(0, 20)}...`)

    // Step 6: Call submitAttestation() on the contract
    console.log(`[EA] Calling submitAttestation() on ${ATTESTATION_VERIFIER}`)

    const txHash = await walletClient.writeContract({
      address: ATTESTATION_VERIFIER,
      abi: SUBMIT_ATTESTATION_ABI,
      functionName: "submitAttestation",
      args: [attestationId, subjectDID, predicateData, signature],
    })

    console.log(`[EA] Transaction sent: ${txHash}`)

    // Step 7: Return success response
    const response: ChainlinkResponse = {
      jobRunID,
      statusCode: 200,
      data: {
        result: txHash,
        txHash,
        proofId,
        attestationId,
        verificationResult: verifyData.result,
      },
    }

    return res.json(response)
  } catch (error) {
    console.error(`[EA] Error:`, error)

    const response: ChainlinkResponse = {
      jobRunID,
      statusCode: 500,
      error: error instanceof Error ? error.message : "Unknown error",
    }

    return res.status(500).json(response)
  }
})

/**
 * Health check endpoint
 */
app.get("/health", (_req, res) => {
  res.json({ status: "ok", address: account.address })
})

app.listen(PORT, () => {
  console.log(`DECO External Adapter running on http://localhost:${PORT}`)
  console.log(`Wallet address: ${account.address}`)
  console.log(`Prover API URL: ${PROVER_API_URL}`)
  console.log(`AttestationVerifier: ${ATTESTATION_VERIFIER}`)
})
