import express from "express"
import { z } from "zod"
import crypto from "node:crypto"
import fs from "node:fs"
import path from "node:path"
import { keccak256, toHex } from "viem"

const PORT = 8787
const DATA_DIR = path.join(process.cwd(), "data")
const STORE_PATH = path.join(DATA_DIR, "store.json")

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

const app = express()
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
  // from DECO "Identity Check" result (stand-in for NHS/GMC)
  valid: z.boolean(),
  checkedAt: z.iso.datetime(),
  expiresAt: z.iso.datetime(),
  attestationBase64: z.string().min(1),
})

// --- Routes ---
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

  // MVP: we trust the uploaded DECO output, and just fingerprint it
  // TODO: actually call DECO sandbox
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

app.listen(PORT, () => {
  console.log(`prover-api listening on http://127.0.0.1:${PORT}`)
})
