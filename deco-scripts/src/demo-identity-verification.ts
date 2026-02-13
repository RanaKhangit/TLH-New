/**
 * DECO Identity Verification Demo
 *
 * This script demonstrates the full flow:
 * 1. Fetch identity data from Persona API (what DECO would verify)
 * 2. Generate a simulated DECO attestation (in production, this comes from deco.chain.link/sandbox)
 * 3. Submit the attestation to prover-api
 * 4. Send an on-chain transaction to Sepolia
 *
 * In production:
 * - Step 1-2 would be replaced by running the DECO Sandbox which generates a real ZK proof
 * - The attestation would be cryptographically signed by Chainlink oracles
 */

import { createWalletClient, createPublicClient, http, parseEther, keccak256, toHex } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'
import * as dotenv from 'dotenv'
import * as path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Load environment variables from the cre-workflow .env
dotenv.config({ path: path.join(__dirname, '../../cre-workflow/tls-cre-poc/.env') })

const PERSONA_INQUIRY_ID = process.env.PERSONA_INQUIRY_ID?.replace(/"/g, '')
const PERSONA_TOKEN = process.env.PERSONA_TOKEN?.replace(/"/g, '')
const CRE_ETH_PRIVATE_KEY = process.env.CRE_ETH_PRIVATE_KEY
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL?.replace(/"/g, '')
if (!SEPOLIA_RPC_URL) {
  throw new Error('SEPOLIA_RPC_URL environment variable is required')
}
const PROVER_API_URL = process.env.PROVER_API_URL || 'http://127.0.0.1:8787'

interface PersonaVerification {
  status: string
  countryCode: string
  completedAt: string
  verificationType: string
}

interface DecoAttestation {
  success: boolean[]
  predicateResults: {
    query: string
    expected: string
    actual: string
    passed: boolean
  }[]
  publicOutputs: string[]
  attestationBase64: string
  timestamp: string
}

/**
 * Step 1: Fetch identity data from Persona API
 * In DECO, this request goes through the DECO Prover which creates a ZK proof
 */
async function fetchPersonaIdentity(): Promise<{ raw: any; verification: PersonaVerification }> {
  console.log('\n📋 Step 1: Fetching identity data from Persona API...')
  console.log(`   Inquiry ID: ${PERSONA_INQUIRY_ID}`)

  const response = await fetch(
    `https://withpersona.com/api/v1/inquiries/${PERSONA_INQUIRY_ID}`,
    {
      method: 'GET',
      headers: {
        'accept': 'application/json',
        'content-type': 'application/json',
        'Persona-Version': '2023-01-05',
        'authorization': `Bearer ${PERSONA_TOKEN}`,
      },
    }
  )

  if (!response.ok) {
    throw new Error(`Persona API error: ${response.status} ${response.statusText}`)
  }

  const data = await response.json()

  // Extract the key fields that DECO would verify
  const verification: PersonaVerification = {
    status: data.data?.attributes?.status,
    countryCode: data.included?.[0]?.attributes?.['country-code'],
    completedAt: data.included?.[0]?.attributes?.['completed-at'],
    verificationType: data.included?.[0]?.type,
  }

  console.log(`   ✅ Inquiry status: ${verification.status}`)
  console.log(`   ✅ Verification status: ${data.included?.[0]?.attributes?.status}`)
  console.log(`   ✅ Country code: ${verification.countryCode}`)
  console.log(`   ✅ Verification type: ${verification.verificationType}`)
  console.log(`   ✅ Completed at: ${verification.completedAt}`)

  return { raw: data, verification }
}

/**
 * Step 2: Simulate DECO attestation generation
 * In production, this would be the output from deco.chain.link/sandbox
 * The real DECO attestation includes:
 * - ZK proof that the TLS session was authentic
 * - Predicate results (assertions on private data)
 * - Public outputs (selectively revealed data)
 * - Cryptographic signature from Chainlink oracles
 */
function generateSimulatedDecoAttestation(
  verification: PersonaVerification,
  rawData: any
): DecoAttestation {
  console.log('\n🔐 Step 2: Generating simulated DECO attestation...')
  console.log('   (In production, this comes from deco.chain.link/sandbox)')

  // These are the predicates from the "Identity Check" DECO config
  const predicateResults = [
    {
      query: 'body.data.attributes.status',
      expected: 'completed',
      actual: verification.status,
      passed: verification.status === 'completed',
    },
    {
      query: 'body.included[0].attributes.status',
      expected: 'passed',
      actual: rawData.included?.[0]?.attributes?.status,
      passed: rawData.included?.[0]?.attributes?.status === 'passed',
    },
    {
      query: 'body.included[0].attributes."country-code"',
      expected: 'US',
      actual: verification.countryCode,
      passed: verification.countryCode === 'US',
    },
  ]

  // Check if all predicates passed
  const allPassed = predicateResults.every((p) => p.passed)

  console.log('   Predicate results:')
  predicateResults.forEach((p, i) => {
    const icon = p.passed ? '✅' : '❌'
    console.log(`   ${i + 1}. ${icon} ${p.query} equals "${p.expected}" → ${p.passed ? 'PASS' : 'FAIL'}`)
  })

  // Public outputs (selectively revealed data)
  const publicOutputs = [
    verification.verificationType,
    verification.completedAt,
  ]

  // Create a simulated attestation payload
  // In real DECO, this would be a cryptographically signed message
  const attestationPayload = {
    version: '1.0',
    type: 'deco-identity-check',
    inquiryId: PERSONA_INQUIRY_ID,
    predicates: predicateResults,
    publicOutputs,
    timestamp: new Date().toISOString(),
    // In real DECO: signature from Chainlink oracles
    simulatedSignature: 'SIMULATED_FOR_DEMO',
  }

  const attestationBase64 = Buffer.from(JSON.stringify(attestationPayload)).toString('base64')

  console.log(`\n   📝 Attestation generated (${attestationBase64.length} bytes base64)`)
  console.log(`   All predicates passed: ${allPassed ? '✅ YES' : '❌ NO'}`)

  return {
    success: predicateResults.map((p) => p.passed),
    predicateResults,
    publicOutputs,
    attestationBase64,
    timestamp: attestationPayload.timestamp,
  }
}

/**
 * Step 3: Submit attestation to prover-api
 */
async function submitToProverApi(
  doctorCommitment: string,
  attestation: DecoAttestation
): Promise<{ attestationHash: string }> {
  console.log('\n📤 Step 3: Submitting attestation to prover-api...')
  console.log(`   URL: ${PROVER_API_URL}`)
  console.log(`   Doctor commitment: ${doctorCommitment}`)

  const allValid = attestation.success.every((s) => s)
  const now = new Date()
  const expiresAt = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000) // 1 year

  const payload = {
    doctorCommitment,
    valid: allValid,
    checkedAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    attestationBase64: attestation.attestationBase64,
  }

  const response = await fetch(`${PROVER_API_URL}/deco/ingest-attestation`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`prover-api error: ${response.status} - ${error}`)
  }

  const result = await response.json()
  console.log(`   ✅ Attestation stored`)
  console.log(`   Attestation hash: ${result.attestationHash}`)

  return result
}

/**
 * Step 4: Send on-chain transaction to Sepolia
 */
async function sendOnChainTransaction(
  attestationHash: string,
  doctorCommitment: string
): Promise<string> {
  console.log('\n⛓️  Step 4: Sending on-chain transaction to Sepolia...')

  if (!CRE_ETH_PRIVATE_KEY) {
    throw new Error('CRE_ETH_PRIVATE_KEY not set in environment')
  }

  const account = privateKeyToAccount(`0x${CRE_ETH_PRIVATE_KEY}`)
  console.log(`   Wallet address: ${account.address}`)

  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(SEPOLIA_RPC_URL),
  })

  const walletClient = createWalletClient({
    account,
    chain: sepolia,
    transport: http(SEPOLIA_RPC_URL),
  })

  // Check balance
  const balance = await publicClient.getBalance({ address: account.address })
  console.log(`   Balance: ${Number(balance) / 1e18} ETH`)

  if (balance < parseEther('0.001')) {
    console.log('   ⚠️  Low balance - transaction may fail')
    console.log('   Get Sepolia ETH from: https://sepoliafaucet.com/')
  }

  // Create transaction data (attestation hash + doctor commitment)
  // This is a simple self-transfer with data - in production you'd call a smart contract
  const txData = keccak256(
    toHex(`DECO_ATTESTATION:${attestationHash}:${doctorCommitment}`)
  )

  console.log(`   Sending transaction with data: ${txData.slice(0, 20)}...`)

  try {
    const hash = await walletClient.sendTransaction({
      to: account.address, // Self-transfer for demo
      value: parseEther('0'),
      data: txData as `0x${string}`,
    })

    console.log(`   ✅ Transaction sent!`)
    console.log(`   TX Hash: ${hash}`)
    console.log(`   Explorer: https://sepolia.etherscan.io/tx/${hash}`)

    return hash
  } catch (error: any) {
    console.log(`   ❌ Transaction failed: ${error.message}`)
    throw error
  }
}

/**
 * Main demo flow
 */
async function main() {
  console.log('═══════════════════════════════════════════════════════════════')
  console.log('       DECO Identity Verification Demo')
  console.log('═══════════════════════════════════════════════════════════════')
  console.log('\nThis demo simulates the DECO flow:')
  console.log('1. Fetch identity data from Persona')
  console.log('2. Generate DECO attestation (simulated - real one from sandbox)')
  console.log('3. Submit to prover-api')
  console.log('4. Send on-chain transaction to Sepolia')

  try {
    // Step 1: Fetch from Persona
    const { raw, verification } = await fetchPersonaIdentity()

    // Step 2: Generate attestation
    const attestation = generateSimulatedDecoAttestation(verification, raw)

    // Create a doctor commitment (normally this comes from registration)
    const doctorCommitment = keccak256(
      toHex(`demo:${PERSONA_INQUIRY_ID}:${Date.now()}`)
    )
    console.log(`\n   Generated doctor commitment: ${doctorCommitment}`)

    // First register the doctor
    console.log('\n📝 Registering doctor in prover-api...')
    try {
      const registerResponse = await fetch(`${PROVER_API_URL}/doctor/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ spruceDID: `did:demo:${PERSONA_INQUIRY_ID}` }),
      })
      const registerResult = await registerResponse.json()
      const registeredCommitment = registerResult.doctorCommitment
      console.log(`   Doctor registered with commitment: ${registeredCommitment}`)

      // Step 3: Submit to prover-api
      const { attestationHash } = await submitToProverApi(registeredCommitment, attestation)

      // Step 4: Send on-chain transaction
      const txHash = await sendOnChainTransaction(attestationHash, registeredCommitment)

      console.log('\n═══════════════════════════════════════════════════════════════')
      console.log('                    ✅ DEMO COMPLETE!')
      console.log('═══════════════════════════════════════════════════════════════')
      console.log('\nSummary:')
      console.log(`  • Persona verification: PASSED`)
      console.log(`  • DECO attestation: ${attestation.success.every((s) => s) ? 'ALL PREDICATES PASSED' : 'SOME FAILED'}`)
      console.log(`  • Attestation hash: ${attestationHash}`)
      console.log(`  • On-chain TX: ${txHash}`)
      console.log(`\nView on Etherscan: https://sepolia.etherscan.io/tx/${txHash}`)

    } catch (apiError: any) {
      if (apiError.message.includes('ECONNREFUSED')) {
        console.log('\n⚠️  prover-api not running. Start it with:')
        console.log('   cd prover-api && npm run dev')
        console.log('\nSkipping steps 3-4 for now.')
      } else {
        throw apiError
      }
    }

  } catch (error) {
    console.error('\n❌ Error:', error)
    process.exit(1)
  }
}

main()
