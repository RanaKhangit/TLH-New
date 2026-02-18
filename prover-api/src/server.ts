import express from "express"
import { z } from "zod"
import crypto from "node:crypto"
import fs from "node:fs"
import path from "node:path"
import { keccak256, toHex, hexToBytes } from "viem"
import { secp256k1 } from "@noble/curves/secp256k1"
import { parse } from "csv-parse/sync"

const PORT = 8787
const DATA_DIR = path.join(process.cwd(), "data")
const STORE_PATH = path.join(DATA_DIR, "store.json")

// Path to GMC dummy data CSV
const GMC_CSV_PATH = path.join(process.cwd(), "..", "dummy-data.csv")

// Path to DECO attestation files (in repo root)
const REPO_ROOT = path.join(process.cwd(), "..")
const ATTESTATION_PATH = path.join(REPO_ROOT, "json-encoded-attestation.json")
const DECODED_DATA_PATH = path.join(REPO_ROOT, "decoded-attested-data.json")

// Deterministic prover keypair for DECO attestation generation.
// In production this would be the TLSNotary's signing key.
const PROVER_PRIV_HEX = keccak256(toHex("TLH_DECO_PROVER_V1")).slice(2)
const PROVER_PUB_UNCOMPRESSED = secp256k1.getPublicKey(PROVER_PRIV_HEX, false)

type Store = {
  doctors: Record<
    string,
    {
      spruceDID: string
      saltHex: string
      inquiryId?: string
    }
  >
  credentials: Record<
    string,
    {
      doctorCommitment: string
      valid: boolean
      attestationHash: string
      checkedAt: string
      expiresAt: string
    }
  >
}

// DECO attestation types
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

function ensureStore(): Store {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR)
  if (!fs.existsSync(STORE_PATH)) {
    const initial: Store = { doctors: {}, credentials: {} }
    fs.writeFileSync(STORE_PATH, JSON.stringify(initial, null, 2))
    return initial
  }
  return JSON.parse(fs.readFileSync(STORE_PATH, "utf8")) as Store
}

function saveStore(store: Store) {
  fs.writeFileSync(STORE_PATH, JSON.stringify(store, null, 2))
}

function newSaltHex(): string {
  return crypto.randomBytes(32).toString("hex")
}

function computeDoctorCommitment(spruceDID: string, saltHex: string): string {
  return keccak256(toHex(`spruceDID:${spruceDID}|salt:${saltHex}`))
}

function computeAttestationHashFromBase64(attestationBase64: string): string {
  const bytes = Buffer.from(attestationBase64, "base64")
  return keccak256(toHex(bytes))
}

/**
 * Verify ECDSA secp256k1 signature using keccak256
 */
function verifyDecoSignature(attestation: DecoAttestation): boolean {
  try {
    const dataHex = attestation.data_hex.replace("0x", "")
    const messageHash = keccak256(`0x${dataHex}`)

    const sigHex = attestation.signature_hex.replace("0x", "")
    const r = BigInt("0x" + sigHex.slice(0, 64))
    const s = BigInt("0x" + sigHex.slice(64, 128))

    const pubKeyHex = attestation.public_key_hex.replace("0x", "")

    const signature = new secp256k1.Signature(r, s)
    const msgHashBytes = hexToBytes(messageHash)
    const pubKeyBytes = hexToBytes(`0x${pubKeyHex}`)

    return secp256k1.verify(signature, msgHashBytes, pubKeyBytes)
  } catch (error) {
    console.error("Signature verification error:", error)
    return false
  }
}

/**
 * Load DECO attestation files from repo root
 */
function loadDecoAttestation(): { attestation: DecoAttestation; decodedData: DecoAttestedData } | null {
  try {
    if (!fs.existsSync(ATTESTATION_PATH) || !fs.existsSync(DECODED_DATA_PATH)) {
      return null
    }

    const attestation = JSON.parse(fs.readFileSync(ATTESTATION_PATH, "utf8")) as DecoAttestation
    const decodedData = JSON.parse(fs.readFileSync(DECODED_DATA_PATH, "utf8")) as DecoAttestedData

    return { attestation, decodedData }
  } catch (error) {
    console.error("Failed to load DECO attestation:", error)
    return null
  }
}

/**
 * Generate a fresh DECO-style attestation for a specific doctor.
 * In production, TLSNotary generates and signs the notarized TLS transcript.
 * This simulates that flow: fetch GMC data → build attestation → sign → verify.
 */
function generateDecoAttestation(gmcRecord: {
  gmcRefNo: string; surname: string; givenName: string;
  registrationStatus: string; revalidationStatus: string;
  qualification: string; yearOfQualification: string;
  placeOfQualification: string; designatedBody: string;
}): { attestation: DecoAttestation; decodedData: DecoAttestedData } {
  const isRegistered = gmcRecord.registrationStatus.includes("Licence")

  const decodedData: DecoAttestedData = {
    success: [isRegistered, true], // [registration predicate, data integrity]
    proof_specs: [{
      client: {
        method: "GET",
        url: `/gmc/lookup?surname=${encodeURIComponent(gmcRecord.surname)}&givenName=${encodeURIComponent(gmcRecord.givenName)}`,
      },
      server: {
        method: "verify-json-response",
        predicate: "body.registrationStatus == 'Registered with Licence'",
      },
      tls_version: "v1.3",
    }],
    public_outputs: [gmcRecord.gmcRefNo, gmcRecord.registrationStatus],
    data_retrieval_time: new Date().toISOString(),
  }

  // Encode to hex (matching TLSNotary attestation format)
  const dataJson = JSON.stringify(decodedData)
  const dataHex = `0x${Buffer.from(dataJson, "utf8").toString("hex")}` as `0x${string}`

  // Sign: keccak256(data_hex) → secp256k1.sign
  const messageHash = keccak256(dataHex)
  const msgHashBytes = hexToBytes(messageHash)
  const sig = secp256k1.sign(msgHashBytes, PROVER_PRIV_HEX)
  const sigCompact = sig.toCompactHex()
  const recovery = (sig.recovery ?? 0).toString(16).padStart(2, "0")
  const signatureHex = `0x${sigCompact}${recovery}`

  const pubKeyHex = `0x${Buffer.from(PROVER_PUB_UNCOMPRESSED).toString("hex")}`

  return {
    attestation: {
      signature_scheme: "ecdsa_secp256k1_keccak256",
      attestation_scheme: "json",
      data_hex: dataHex,
      signature_hex: signatureHex,
      public_key_hex: pubKeyHex,
    },
    decodedData,
  }
}

/**
 * Look up a doctor from GMC CSV data and return structured result.
 */
function lookupDoctor(surname: string, givenName: string) {
  const records = loadGMCData()
  const match = records.find(
    (r) =>
      r.Surname.toLowerCase() === surname.toLowerCase() &&
      r["Given Name"].toLowerCase() === givenName.toLowerCase()
  )
  if (!match) return null
  return {
    gmcRefNo: match["GMC Ref No"],
    surname: match.Surname,
    givenName: match["Given Name"],
    registrationStatus: match["Registration Status"],
    revalidationStatus: match["Revalidation Status"],
    qualification: match.Qualification,
    yearOfQualification: match["Year Of Qualification"],
    placeOfQualification: match["Place of Qualification"],
    designatedBody: match["Designated Body"],
  }
}

const app = express()
app.use((_req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*")
  res.header("Access-Control-Allow-Headers", "Content-Type")
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  if (_req.method === "OPTIONS") return res.sendStatus(204)
  next()
})
app.use(express.json({ limit: "10mb" }))

// --- Schemas ---
const RegisterDoctorSchema = z.object({
  spruceDID: z.string().min(8),
})

const LinkInquirySchema = z.object({
  doctorCommitment: z.string().regex(/^0x[0-9a-fA-F]{64}$/),
  inquiryId: z.string().min(3),
})

const IngestSchema = z.object({
  doctorCommitment: z.string().regex(/^0x[0-9a-fA-F]{64}$/),
  valid: z.boolean(),
  checkedAt: z.string().datetime(),
  expiresAt: z.string().datetime(),
  attestationBase64: z.string().min(1),
})

// --- DECO Verification Endpoints (for Chainlink node) ---

/**
 * GET /deco/attestation
 * Returns the raw DECO attestation for the Chainlink node to fetch
 */
app.get("/deco/attestation", (req, res) => {
  const surname = req.query.surname as string | undefined
  const givenName = req.query.givenName as string | undefined

  if (surname && givenName) {
    const doctor = lookupDoctor(surname, givenName)
    if (!doctor) {
      return res.status(404).json({ error: `Doctor not found: ${givenName} ${surname}` })
    }
    const { attestation } = generateDecoAttestation(doctor)
    return res.json(attestation)
  }

  const data = loadDecoAttestation()
  if (!data) {
    return res.status(404).json({ error: "No DECO attestation files found" })
  }
  return res.json(data.attestation)
})

/**
 * GET /deco/verify
 * Verifies the DECO attestation and returns PASS/FAIL result
 * This is the main endpoint the Chainlink node will call
 */
app.get("/deco/verify", (req, res) => {
  const surname = req.query.surname as string | undefined
  const givenName = req.query.givenName as string | undefined

  console.log(`[DECO] Verification request${surname ? ` for ${givenName} ${surname}` : " (static fallback)"}`)

  let attestation: DecoAttestation
  let decodedData: DecoAttestedData

  if (surname && givenName) {
    // Dynamic mode: look up doctor in GMC register, generate fresh attestation
    const doctor = lookupDoctor(surname, givenName)
    if (!doctor) {
      console.log(`[DECO] Doctor not found: ${givenName} ${surname}`)
      return res.json({
        result: "FAIL",
        reason: `Doctor not found in GMC register: ${givenName} ${surname}`,
        timestamp: new Date().toISOString(),
      })
    }
    console.log(`[DECO] GMC record: ${doctor.givenName} ${doctor.surname} — ${doctor.registrationStatus}`)
    const generated = generateDecoAttestation(doctor)
    attestation = generated.attestation
    decodedData = generated.decodedData
  } else {
    // Static fallback: read pre-computed attestation files
    const data = loadDecoAttestation()
    if (!data) {
      console.log("[DECO] No attestation files found")
      return res.json({
        result: "FAIL",
        reason: "No attestation files found",
        timestamp: new Date().toISOString(),
      })
    }
    attestation = data.attestation
    decodedData = data.decodedData
  }

  // Step 1: Verify ECDSA signature (same path for dynamic and static)
  const signatureValid = verifyDecoSignature(attestation)
  console.log(`[DECO] Signature verification: ${signatureValid ? "PASS" : "FAIL"}`)

  if (!signatureValid) {
    return res.json({
      result: "FAIL",
      reason: "Invalid ECDSA signature on attestation",
      timestamp: new Date().toISOString(),
    })
  }

  // Step 2: Check all predicates passed
  const predicatesPassed = decodedData.success.every((s) => s === true)
  console.log(`[DECO] Predicates: ${predicatesPassed ? "PASS" : "FAIL"} (${decodedData.success.join(", ")})`)

  if (!predicatesPassed) {
    return res.json({
      result: "FAIL",
      reason: "Registration predicate failed — doctor not registered with licence",
      gmcRefNo: decodedData.public_outputs[0] || "",
      registrationStatus: decodedData.public_outputs[1] || "",
      timestamp: new Date().toISOString(),
    })
  }

  // Step 3: Build response with proof details
  const proofId = attestation.signature_hex.slice(2, 20)

  console.log(`[DECO] Verification PASSED — proofId=${proofId}`)

  return res.json({
    result: "PASS",
    reason: "Signature valid, registration predicate satisfied",
    proofId,
    verificationType: "GMC_REGISTRATION",
    completedAt: decodedData.data_retrieval_time,
    dataRetrievalTime: decodedData.data_retrieval_time,
    gmcRefNo: decodedData.public_outputs[0] || "",
    registrationStatus: decodedData.public_outputs[1] || "",
    attestation,
    timestamp: new Date().toISOString(),
  })
})

/**
 * POST /deco/verify
 * Alternative POST endpoint that accepts attestation in request body
 * Useful if attestation is passed directly rather than read from file
 */
app.post("/deco/verify", (req, res) => {
  console.log("[DECO] POST Verification request received")

  const { attestation, decodedData } = req.body

  if (!attestation || !decodedData) {
    return res.json({
      result: "FAIL",
      reason: "Missing attestation or decodedData in request body",
      inquiryId: "",
      timestamp: new Date().toISOString(),
    })
  }

  // Verify signature
  const signatureValid = verifyDecoSignature(attestation)
  console.log(`[DECO] Signature verification: ${signatureValid ? "PASS" : "FAIL"}`)

  if (!signatureValid) {
    return res.json({
      result: "FAIL",
      reason: "Invalid signature",
      inquiryId: "",
      timestamp: new Date().toISOString(),
    })
  }

  // Check predicates
  const predicatesPassed = decodedData.success.every((s: boolean) => s === true)
  console.log(`[DECO] Predicates check: ${predicatesPassed ? "PASS" : "FAIL"}`)

  if (!predicatesPassed) {
    return res.json({
      result: "FAIL",
      reason: "Predicates failed",
      inquiryId: "",
      timestamp: new Date().toISOString(),
    })
  }

  const proofId = attestation.signature_hex.slice(2, 20)

  return res.json({
    result: "PASS",
    reason: "All checks passed",
    proofId: proofId,
    verificationType: decodedData.public_outputs[0] || "",
    completedAt: decodedData.public_outputs[1] || "",
    timestamp: new Date().toISOString(),
  })
})

// --- Original Routes ---
app.post("/doctor/register", (req, res) => {
  const parsed = RegisterDoctorSchema.safeParse(req.body)
  if (!parsed.success) return res.status(400).json(parsed.error.format())

  const { spruceDID } = parsed.data
  const store = ensureStore()

  const existing = Object.entries(store.doctors).find(([, v]) => v.spruceDID === spruceDID)
  if (existing) {
    const [doctorCommitment] = existing
    return res.json({ doctorCommitment })
  }

  const saltHex = newSaltHex()
  const doctorCommitment = computeDoctorCommitment(spruceDID, saltHex)

  store.doctors[doctorCommitment] = { spruceDID, saltHex }
  saveStore(store)

  return res.json({ doctorCommitment })
})

app.post("/doctor/link-inquiry", (req, res) => {
  const parsed = LinkInquirySchema.safeParse(req.body)
  if (!parsed.success) return res.status(400).json(parsed.error.format())

  const { doctorCommitment, inquiryId } = parsed.data
  const store = ensureStore()

  if (!store.doctors[doctorCommitment]) {
    return res.status(404).json({ error: "Unknown doctorCommitment. Register doctor first." })
  }

  store.doctors[doctorCommitment].inquiryId = inquiryId
  saveStore(store)
  return res.json({ ok: true })
})

app.post("/deco/ingest-attestation", (req, res) => {
  const parsed = IngestSchema.safeParse(req.body)
  if (!parsed.success) return res.status(400).json(parsed.error.format())

  const { doctorCommitment, valid, checkedAt, expiresAt, attestationBase64 } = parsed.data
  const store = ensureStore()

  if (!store.doctors[doctorCommitment]) {
    return res.status(404).json({ error: "Unknown doctorCommitment. Register doctor first." })
  }

  const attestationHash = computeAttestationHashFromBase64(attestationBase64)

  store.credentials[doctorCommitment] = {
    doctorCommitment,
    valid,
    attestationHash,
    checkedAt,
    expiresAt,
  }
  saveStore(store)

  return res.json({
    ok: true,
    doctorCommitment,
    attestationHash,
  })
})

app.get("/credential/latest/:doctorCommitment", (req, res) => {
  const doctorCommitment = req.params.doctorCommitment
  const store = ensureStore()

  const cred = store.credentials[doctorCommitment]
  if (!cred) return res.status(404).json({ error: "No credential found for doctorCommitment" })

  return res.json(cred)
})

app.get("/health", (_req, res) => res.json({ ok: true }))

// --- GMC Registration Lookup ---

interface GMCRecord {
  "GMC Ref No": string
  Surname: string
  "Given Name": string
  Gender: string
  Qualification: string
  "Year Of Qualification": string
  "Place of Qualification": string
  "Registration Status": string
  "Revalidation Status": string
  "Designated Body": string
  [key: string]: string
}

/**
 * Load and parse the GMC CSV file
 */
function loadGMCData(): GMCRecord[] {
  try {
    if (!fs.existsSync(GMC_CSV_PATH)) {
      console.error(`GMC CSV file not found at ${GMC_CSV_PATH}`)
      return []
    }
    const csvContent = fs.readFileSync(GMC_CSV_PATH, "utf8")
    const records = parse(csvContent, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
    }) as GMCRecord[]
    return records
  } catch (error) {
    console.error("Failed to load GMC data:", error)
    return []
  }
}

/**
 * GET /gmc/lookup
 * Lookup doctor registration status by surname and given name
 *
 * Query params:
 *   - surname: Doctor's surname (required)
 *   - givenName: Doctor's given name (required)
 *
 * This endpoint is designed to be called by the DECO Sandbox
 */
app.get("/gmc/lookup", (req, res) => {
  const surname = req.query.surname as string
  const givenName = req.query.givenName as string

  console.log(`[GMC] Lookup request - Surname: "${surname}", Given Name: "${givenName}"`)

  if (!surname || !givenName) {
    return res.status(400).json({
      error: "Missing required query parameters: surname and givenName",
    })
  }

  const records = loadGMCData()
  if (records.length === 0) {
    return res.status(500).json({
      error: "Failed to load GMC data",
    })
  }

  // Case-insensitive search
  const match = records.find(
    (r) =>
      r.Surname.toLowerCase() === surname.toLowerCase() &&
      r["Given Name"].toLowerCase() === givenName.toLowerCase()
  )

  if (!match) {
    console.log(`[GMC] No match found for "${surname}, ${givenName}"`)
    return res.status(404).json({
      found: false,
      surname,
      givenName,
      message: "Doctor not found in GMC register",
    })
  }

  console.log(`[GMC] Found: ${match["Given Name"]} ${match.Surname} - Status: ${match["Registration Status"]}`)

  return res.json({
    found: true,
    gmcRefNo: match["GMC Ref No"],
    surname: match.Surname,
    givenName: match["Given Name"],
    registrationStatus: match["Registration Status"],
    revalidationStatus: match["Revalidation Status"],
    qualification: match.Qualification,
    yearOfQualification: match["Year Of Qualification"],
    placeOfQualification: match["Place of Qualification"],
    designatedBody: match["Designated Body"],
  })
})

/**
 * POST /gmc/lookup
 * Alternative POST endpoint for DECO Sandbox (if it prefers POST)
 */
app.post("/gmc/lookup", (req, res) => {
  const { surname, givenName } = req.body

  console.log(`[GMC] POST Lookup request - Surname: "${surname}", Given Name: "${givenName}"`)

  if (!surname || !givenName) {
    return res.status(400).json({
      error: "Missing required fields: surname and givenName",
    })
  }

  const records = loadGMCData()
  if (records.length === 0) {
    return res.status(500).json({
      error: "Failed to load GMC data",
    })
  }

  // Case-insensitive search
  const match = records.find(
    (r) =>
      r.Surname.toLowerCase() === surname.toLowerCase() &&
      r["Given Name"].toLowerCase() === givenName.toLowerCase()
  )

  if (!match) {
    console.log(`[GMC] No match found for "${surname}, ${givenName}"`)
    return res.status(404).json({
      found: false,
      surname,
      givenName,
      message: "Doctor not found in GMC register",
    })
  }

  console.log(`[GMC] Found: ${match["Given Name"]} ${match.Surname} - Status: ${match["Registration Status"]}`)

  return res.json({
    found: true,
    gmcRefNo: match["GMC Ref No"],
    surname: match.Surname,
    givenName: match["Given Name"],
    registrationStatus: match["Registration Status"],
    revalidationStatus: match["Revalidation Status"],
    qualification: match.Qualification,
    yearOfQualification: match["Year Of Qualification"],
    placeOfQualification: match["Place of Qualification"],
    designatedBody: match["Designated Body"],
  })
})

// GET /gmc/doctors - List all available doctors from CSV
app.get("/gmc/doctors", (_req, res) => {
  const data = loadGMCData()
  const doctors = data.map((row) => ({
    surname: row["Surname"],
    givenName: row["Given Name"],
    gmcRefNo: row["GMC Ref No"],
    registrationStatus: row["Registration Status"],
  }))
  return res.json(doctors)
})

app.listen(PORT, () => {
  console.log(`prover-api listening on http://127.0.0.1:${PORT}`)
  console.log(`DECO verification endpoint: http://127.0.0.1:${PORT}/deco/verify`)
  console.log(`GMC lookup endpoint: http://127.0.0.1:${PORT}/gmc/lookup?surname=X&givenName=Y`)
})
