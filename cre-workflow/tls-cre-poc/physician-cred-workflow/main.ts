import {
  cre,
  decodeJson,
  ok,
  json,
  Runner,
  ConsensusAggregationByFields,
  identical,
  type Runtime,
  type HTTPPayload,
  type HTTPSendRequester,
} from "@chainlink/cre-sdk"

type Config = {
  proverApiUrl: string
}

type Input = {
  physicianCommitment: string
}

type CredentialEnvelope = {
  physicianCommitment: string
  valid: boolean
  attestationHash: string
  checkedAt: string
  expiresAt: string
}

// CRE-node executed function: each node calls our in-house API
const fetchEnvelope = (
  sendRequester: HTTPSendRequester,
  proverApiUrl: string,
  physicianCommitment: string
): CredentialEnvelope => {
  const response = sendRequester
    .sendRequest({
      url: `${proverApiUrl}/credential/latest/${physicianCommitment}`,
      method: "GET",
    })
    .result()

  if (!ok(response)) {
    throw new Error(`prover-api request failed with status ${response.statusCode}`)
  }

  return json(response) as CredentialEnvelope
}

const initWorkflow = (_config: Config) => {
  const http = new cre.capabilities.HTTPCapability()

  // TODO!!!!!!:
  // {} is only valid for local simulation. Deployed workflows must set authorizedKeys.
  const trigger = http.trigger({})

  return [cre.handler(trigger, onHttpTrigger)]
}

const onHttpTrigger = (runtime: Runtime<Config>, payload: HTTPPayload) => {
  if (!payload.input || payload.input.length === 0) {
    return { ok: false, error: "Empty request body" }
  }

  const input = decodeJson(payload.input) as Partial<Input>
  if (!input.physicianCommitment || typeof input.physicianCommitment !== "string") {
    return { ok: false, error: "Missing physicianCommitment" }
  }

  const httpClient = new cre.capabilities.HTTPClient()

  // High-level sendRequest: CRE runs this on nodes and aggregates.
  const envelope = httpClient
    .sendRequest(
      runtime,
      (sr, physicianCommitment: string) => fetchEnvelope(sr, runtime.config.proverApiUrl, physicianCommitment),
      ConsensusAggregationByFields<CredentialEnvelope>({
        physicianCommitment: identical,
        valid: identical,
        attestationHash: identical,
        checkedAt: identical,
        expiresAt: identical,
      })
    )(input.physicianCommitment)
    .result()

  // Dummy processing (MVP): derive just a boolen for now where Identity Sandbox result (true/false) is our final result. In this case its just the same as the valid flag.
  const processed = {
    physicianCommitment: envelope.physicianCommitment,
    valid: envelope.valid,
    // example “processing”: create a final flag that you’d submit onchain
    verifiedFlag: envelope.valid === true,
    attestationHash: envelope.attestationHash,
    checkedAt: envelope.checkedAt,
    expiresAt: envelope.expiresAt,
  }

  runtime.log(`Processed: ${JSON.stringify(processed)}`)
  return processed
}

export async function main() {
  const runner = await Runner.newRunner<Config>()
  await runner.run(initWorkflow)
}

main()
