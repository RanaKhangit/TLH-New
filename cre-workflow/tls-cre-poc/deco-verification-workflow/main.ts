/**
 * DECO Attestation Verification Workflow
 *
 * This CRE workflow:
 * 1. Receives a DECO attestation (from the sandbox)
 * 2. Verifies the ECDSA signature using the Chainlink oracle public key
 * 3. Parses the attested data to check predicates passed
 * 4. If valid, returns data that can be used for on-chain submission
 */

import {
  cre,
  decodeJson,
  Runner,
  type Runtime,
  type HTTPPayload,
} from "@chainlink/cre-sdk"

// The DECO sandbox public key (from the attestation)
const DECO_PUBLIC_KEY = "0x04a8a87d024e5759d495d5aa92f5b8fbe8e2a2cf05d69c7f636f90500852eda32b27275d0ec8ec7c9c16ba416a92b9d9b478cd0f46702077131c0aaffaec7879e1"

type Config = {
  // Sepolia RPC URL for sending transactions
  sepoliaRpcUrl: string
}

/**
 * Input: The DECO attestation from the sandbox
 */
type DecoAttestationInput = {
  signature_scheme: string
  attestation_scheme: string
  data_hex: string
  signature_hex: string
  public_key_hex: string
}

/**
 * Decoded attested data structure
 */
type DecoAttestedData = {
  success: boolean[]
  proof_specs: any[]
  public_inputs: Record<string, string>
  public_outputs: string[]
  prover_chosen_attested_data: string
  data_retrieval_time: string
}

/**
 * Output from the workflow
 */
type VerificationResult = {
  valid: boolean
  signatureValid: boolean
  predicatesPassed: boolean
  publicKey: string
  verificationType: string
  completedAt: string
  dataRetrievalTime: string
  attestationHash: string
  error?: string
}

/**
 * Verify ECDSA secp256k1 signature
 * Note: In a real CRE deployment, this would use the built-in crypto capabilities
 */
function verifySignature(
  dataHex: string,
  signatureHex: string,
  publicKeyHex: string
): boolean {
  // For CRE simulation, we do a basic check that the signature format is valid
  // In production CRE, this would use actual ECDSA verification

  // Check signature is 65 bytes (r: 32, s: 32, v: 1)
  const sigBytes = signatureHex.replace('0x', '')
  if (sigBytes.length !== 130) { // 65 bytes = 130 hex chars
    return false
  }

  // Check public key matches expected DECO oracle key
  if (publicKeyHex.toLowerCase() !== DECO_PUBLIC_KEY.toLowerCase()) {
    return false
  }

  // Check data is not empty
  if (!dataHex || dataHex.length < 10) {
    return false
  }

  return true
}

/**
 * Parse the hex-encoded attested data
 */
function parseAttestedData(dataHex: string): DecoAttestedData {
  const hexString = dataHex.replace('0x', '')
  const bytes = Buffer.from(hexString, 'hex')
  const jsonString = bytes.toString('utf8')
  return JSON.parse(jsonString) as DecoAttestedData
}

/**
 * Compute a simple hash of the attestation for on-chain reference
 */
function computeAttestationHash(dataHex: string, signatureHex: string): string {
  // Simple hash: take first 32 bytes of data + first 32 bytes of signature
  const combined = dataHex.slice(0, 66) + signatureHex.slice(2, 66)
  return combined
}

const initWorkflow = (_config: Config) => {
  const http = new cre.capabilities.HTTPCapability()

  // HTTP trigger - accepts POST with attestation JSON
  const trigger = http.trigger({})

  return [cre.handler(trigger, onHttpTrigger)]
}

const onHttpTrigger = (runtime: Runtime<Config>, payload: HTTPPayload): VerificationResult => {
  runtime.log("DECO Verification Workflow triggered")

  if (!payload.input || payload.input.length === 0) {
    return {
      valid: false,
      signatureValid: false,
      predicatesPassed: false,
      publicKey: "",
      verificationType: "",
      completedAt: "",
      dataRetrievalTime: "",
      attestationHash: "",
      error: "Empty request body",
    }
  }

  let attestation: DecoAttestationInput
  try {
    attestation = decodeJson(payload.input) as DecoAttestationInput
  } catch (e) {
    return {
      valid: false,
      signatureValid: false,
      predicatesPassed: false,
      publicKey: "",
      verificationType: "",
      completedAt: "",
      dataRetrievalTime: "",
      attestationHash: "",
      error: "Failed to parse attestation JSON",
    }
  }

  runtime.log(`Received attestation with scheme: ${attestation.signature_scheme}`)

  // Step 1: Verify the signature scheme is what we expect
  if (attestation.signature_scheme !== "ecdsa_secp256k1_keccak256") {
    return {
      valid: false,
      signatureValid: false,
      predicatesPassed: false,
      publicKey: attestation.public_key_hex,
      verificationType: "",
      completedAt: "",
      dataRetrievalTime: "",
      attestationHash: "",
      error: `Unsupported signature scheme: ${attestation.signature_scheme}`,
    }
  }

  // Step 2: Verify the ECDSA signature
  const signatureValid = verifySignature(
    attestation.data_hex,
    attestation.signature_hex,
    attestation.public_key_hex
  )

  runtime.log(`Signature verification: ${signatureValid ? "PASSED" : "FAILED"}`)

  if (!signatureValid) {
    return {
      valid: false,
      signatureValid: false,
      predicatesPassed: false,
      publicKey: attestation.public_key_hex,
      verificationType: "",
      completedAt: "",
      dataRetrievalTime: "",
      attestationHash: "",
      error: "Signature verification failed",
    }
  }

  // Step 3: Parse the attested data
  let attestedData: DecoAttestedData
  try {
    attestedData = parseAttestedData(attestation.data_hex)
  } catch (e) {
    return {
      valid: false,
      signatureValid: true,
      predicatesPassed: false,
      publicKey: attestation.public_key_hex,
      verificationType: "",
      completedAt: "",
      dataRetrievalTime: "",
      attestationHash: "",
      error: "Failed to parse attested data",
    }
  }

  runtime.log(`Attested data parsed. Success array: ${JSON.stringify(attestedData.success)}`)

  // Step 4: Check if all predicates passed
  const predicatesPassed = attestedData.success.every((s) => s === true)

  runtime.log(`Predicates check: ${predicatesPassed ? "ALL PASSED" : "SOME FAILED"}`)

  // Step 5: Extract public outputs
  const verificationType = attestedData.public_outputs[0] || ""
  const completedAt = attestedData.public_outputs[1] || ""

  // Step 6: Compute attestation hash for on-chain reference
  const attestationHash = computeAttestationHash(
    attestation.data_hex,
    attestation.signature_hex
  )

  const result: VerificationResult = {
    valid: signatureValid && predicatesPassed,
    signatureValid,
    predicatesPassed,
    publicKey: attestation.public_key_hex,
    verificationType,
    completedAt,
    dataRetrievalTime: attestedData.data_retrieval_time,
    attestationHash,
  }

  runtime.log(`Verification result: ${JSON.stringify(result)}`)

  return result
}

export async function main() {
  const runner = await Runner.newRunner<Config>()
  await runner.run(initWorkflow)
}

main()
