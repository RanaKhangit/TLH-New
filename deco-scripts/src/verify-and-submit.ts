/**
 * DECO Attestation Verification and On-Chain Submission
 *
 * This script:
 * 1. Loads the real DECO attestation from the sandbox output files
 * 2. Verifies the ECDSA signature (secp256k1 + keccak256)
 * 3. Parses and validates the attested data
 * 4. Sends an on-chain transaction to Sepolia with the verification result
 */

import {
  createWalletClient,
  createPublicClient,
  http,
  parseEther,
  keccak256,
  toHex,
  recoverPublicKey,
  hexToBytes,
  bytesToHex,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'
import * as dotenv from 'dotenv'
import * as path from 'path'
import * as fs from 'fs'
import { fileURLToPath } from 'url'
import { secp256k1 } from '@noble/curves/secp256k1'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../cre-workflow/tls-cre-poc/.env') })

const CRE_ETH_PRIVATE_KEY = process.env.CRE_ETH_PRIVATE_KEY
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL?.replace(/"/g, '')
if (!SEPOLIA_RPC_URL) {
  throw new Error('SEPOLIA_RPC_URL environment variable is required')
}

// Paths to the DECO attestation files
const ATTESTATION_PATH = path.join(__dirname, '../../json-encoded-attestation.json')
const DECODED_DATA_PATH = path.join(__dirname, '../../decoded-attested-data.json')

interface DecoAttestation {
  signature_scheme: string
  attestation_scheme: string
  data_hex: string
  signature_hex: string
  public_key_hex: string
}

interface DecoAttestedData {
  success: boolean[]
  proof_specs: any[]
  public_outputs: string[]
  data_retrieval_time: string
}

/**
 * Load and parse the DECO attestation files
 */
function loadAttestation(): { attestation: DecoAttestation; decodedData: DecoAttestedData } {
  console.log('\n📂 Loading DECO attestation files...')

  const attestationRaw = fs.readFileSync(ATTESTATION_PATH, 'utf8')
  const decodedDataRaw = fs.readFileSync(DECODED_DATA_PATH, 'utf8')

  // Parse JSON (handle the weird formatting from the sandbox)
  const attestation = JSON.parse(attestationRaw) as DecoAttestation
  const decodedData = JSON.parse(decodedDataRaw) as DecoAttestedData

  console.log(`   ✅ Loaded attestation (signature scheme: ${attestation.signature_scheme})`)
  console.log(`   ✅ Loaded decoded data (${decodedData.success.length} predicates)`)

  return { attestation, decodedData }
}

/**
 * Verify the ECDSA secp256k1 signature using keccak256
 */
function verifyDecoSignature(attestation: DecoAttestation): boolean {
  console.log('\n🔐 Verifying ECDSA signature...')

  try {
    // The data that was signed (hex encoded)
    const dataHex = attestation.data_hex.replace('0x', '')
    const dataBytes = hexToBytes(`0x${dataHex}`)

    // Hash the data with keccak256 (as per the signature scheme)
    const messageHash = keccak256(`0x${dataHex}`)
    console.log(`   Message hash: ${messageHash.slice(0, 20)}...`)

    // Parse the signature (65 bytes: r(32) + s(32) + v(1))
    const sigHex = attestation.signature_hex.replace('0x', '')
    const r = BigInt('0x' + sigHex.slice(0, 64))
    const s = BigInt('0x' + sigHex.slice(64, 128))
    const v = parseInt(sigHex.slice(128, 130), 16)

    console.log(`   Signature r: ${r.toString(16).slice(0, 16)}...`)
    console.log(`   Signature s: ${s.toString(16).slice(0, 16)}...`)
    console.log(`   Signature v: ${v}`)

    // Parse the public key (uncompressed: 04 + x(32) + y(32))
    const pubKeyHex = attestation.public_key_hex.replace('0x', '')
    console.log(`   Public key: ${attestation.public_key_hex.slice(0, 20)}...`)

    // Verify using @noble/curves
    const signature = new secp256k1.Signature(r, s)
    const msgHashBytes = hexToBytes(messageHash)
    const pubKeyBytes = hexToBytes(`0x${pubKeyHex}`)

    // secp256k1 verify expects compressed or uncompressed public key
    const isValid = secp256k1.verify(signature, msgHashBytes, pubKeyBytes)

    console.log(`   ✅ Signature verification: ${isValid ? 'VALID' : 'INVALID'}`)
    return isValid

  } catch (error: any) {
    console.log(`   ❌ Signature verification error: ${error.message}`)
    return false
  }
}

/**
 * Validate the attested data
 */
function validateAttestedData(decodedData: DecoAttestedData): {
  valid: boolean
  predicatesPassed: boolean
  verificationType: string
  completedAt: string
} {
  console.log('\n📋 Validating attested data...')

  // Check all predicates passed
  const predicatesPassed = decodedData.success.every(s => s === true)
  console.log(`   Predicates: ${decodedData.success.map(s => s ? '✅' : '❌').join(' ')}`)
  console.log(`   All predicates passed: ${predicatesPassed ? 'YES' : 'NO'}`)

  // Extract public outputs
  const verificationType = decodedData.public_outputs[0] || 'unknown'
  const completedAt = decodedData.public_outputs[1] || 'unknown'

  console.log(`   Verification type: ${verificationType}`)
  console.log(`   Completed at: ${completedAt}`)
  console.log(`   Data retrieval time: ${decodedData.data_retrieval_time}`)

  return {
    valid: predicatesPassed,
    predicatesPassed,
    verificationType,
    completedAt,
  }
}

/**
 * Send on-chain transaction to Sepolia
 */
async function sendOnChainTransaction(
  attestation: DecoAttestation,
  validationResult: { valid: boolean; verificationType: string; completedAt: string }
): Promise<string> {
  console.log('\n⛓️  Sending on-chain transaction to Sepolia...')

  if (!CRE_ETH_PRIVATE_KEY) {
    throw new Error('CRE_ETH_PRIVATE_KEY not set')
  }

  const account = privateKeyToAccount(`0x${CRE_ETH_PRIVATE_KEY}`)
  console.log(`   Wallet: ${account.address}`)

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

  // Create transaction data encoding the verification result
  // In production, this would call a smart contract
  const txData = {
    type: 'DECO_IDENTITY_VERIFICATION',
    valid: validationResult.valid,
    verificationType: validationResult.verificationType,
    completedAt: validationResult.completedAt,
    attestationSignature: attestation.signature_hex.slice(0, 66), // First 32 bytes
    publicKey: attestation.public_key_hex.slice(0, 42), // First 20 bytes
    timestamp: new Date().toISOString(),
  }

  const encodedData = keccak256(toHex(JSON.stringify(txData)))
  console.log(`   TX data hash: ${encodedData.slice(0, 20)}...`)

  const hash = await walletClient.sendTransaction({
    to: account.address, // Self-transfer for demo
    value: parseEther('0'),
    data: encodedData as `0x${string}`,
  })

  console.log(`   ✅ Transaction sent!`)
  console.log(`   TX Hash: ${hash}`)

  return hash
}

/**
 * Main flow
 */
async function main() {
  console.log('═══════════════════════════════════════════════════════════════')
  console.log('     DECO Attestation Verification & On-Chain Submission')
  console.log('═══════════════════════════════════════════════════════════════')

  try {
    // Step 1: Load the DECO attestation
    const { attestation, decodedData } = loadAttestation()

    // Step 2: Verify the signature
    const signatureValid = verifyDecoSignature(attestation)

    // Step 3: Validate the attested data
    const validationResult = validateAttestedData(decodedData)

    // Step 4: Determine overall validity
    const overallValid = signatureValid && validationResult.valid

    console.log('\n═══════════════════════════════════════════════════════════════')
    console.log('                    VERIFICATION SUMMARY')
    console.log('═══════════════════════════════════════════════════════════════')
    console.log(`   Signature Valid:     ${signatureValid ? '✅ YES' : '❌ NO'}`)
    console.log(`   Predicates Passed:   ${validationResult.predicatesPassed ? '✅ YES' : '❌ NO'}`)
    console.log(`   Overall Valid:       ${overallValid ? '✅ YES' : '❌ NO'}`)
    console.log(`   Verification Type:   ${validationResult.verificationType}`)
    console.log(`   Completed At:        ${validationResult.completedAt}`)

    if (overallValid) {
      // Step 5: Send on-chain transaction
      const txHash = await sendOnChainTransaction(attestation, validationResult)

      console.log('\n═══════════════════════════════════════════════════════════════')
      console.log('                    ✅ SUCCESS!')
      console.log('═══════════════════════════════════════════════════════════════')
      console.log(`\n   View on Etherscan:`)
      console.log(`   https://sepolia.etherscan.io/tx/${txHash}`)
    } else {
      console.log('\n❌ Verification failed - no transaction sent')
    }

  } catch (error) {
    console.error('\n❌ Error:', error)
    process.exit(1)
  }
}

main()
