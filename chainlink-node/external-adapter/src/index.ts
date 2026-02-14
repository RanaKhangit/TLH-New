/**
 * DECO External Adapter for Chainlink
 *
 * This adapter:
 * 1. Receives requests from Chainlink job
 * 2. Calls prover-api to verify DECO attestation
 * 3. Sends a transaction with PASS/FAIL result + proofId
 * 4. Returns the txHash to Chainlink
 */

import express from "express"
import { createWalletClient, http, toHex, parseEther } from "viem"
import { privateKeyToAccount } from "viem/accounts"
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

const app = express()
app.use(express.json())

// Create wallet client for sending transactions
const account = privateKeyToAccount(PRIVATE_KEY)
const walletClient = createWalletClient({
  account,
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
    [key: string]: unknown
  }
}

interface ChainlinkResponse {
  jobRunID: string | number
  statusCode: number
  data?: {
    result: string
    txHash?: string
    proofId?: string
    verificationResult?: string
  }
  error?: string
}

/**
 * Chainlink External Adapter endpoint
 * POST /
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

    const verifyData = await verifyResponse.json() as DecoVerifyResponse
    console.log(`[EA] Verification result: ${verifyData.result}`)

    // Step 2: Build transaction data
    // Format: "RESULT|proofId" encoded as hex
    const proofId = verifyData.proofId || "unknown"
    const txDataString = `${verifyData.result}|${proofId}`
    const txData = toHex(txDataString)

    console.log(`[EA] TX data: "${txDataString}" -> ${txData}`)

    // Step 3: Send transaction to self with the result data
    console.log(`[EA] Sending transaction from ${account.address}`)

    const txHash = await walletClient.sendTransaction({
      to: account.address, // Send to self
      value: parseEther("0"), // No ETH value
      data: txData as `0x${string}`,
    })

    console.log(`[EA] Transaction sent: ${txHash}`)

    // Step 4: Return success response to Chainlink
    const response: ChainlinkResponse = {
      jobRunID,
      statusCode: 200,
      data: {
        result: txHash,
        txHash: txHash,
        proofId: proofId,
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
})
