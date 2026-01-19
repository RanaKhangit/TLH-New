/**
 * DECO Sandbox Configuration
 *
 * This module contains the configuration for running DECO proofs against the Persona API.
 * The configuration matches the "Identity Check" template from the DECO sandbox.
 */

export interface DecoSecretVariable {
  name: string
  value: string
}

export interface DecoPublicVariable {
  name: string
  value: string
}

export interface DecoPredicate {
  op: "equal" | "not_equal" | "greater_than" | "less_than" | "contains"
  queries_for_scalars: string[]
  public_operands: string[]
}

export interface DecoAssertionOnPublicData {
  script: string
}

export interface DecoConfig {
  secret_variables: DecoSecretVariable[]
  public_variables: DecoPublicVariable[]
  request: {
    method: "GET" | "POST" | "PUT" | "DELETE"
    url: string
    headers: Record<string, string>
    body?: string
  }
  proof_spec: {
    predicates: DecoPredicate[]
    public_fields: string[]
    assertions_on_public_data: DecoAssertionOnPublicData[]
  }
}

/**
 * Creates the DECO configuration for Persona Identity Check
 * This replicates the pre-loaded "Identity Check" configuration from the DECO sandbox
 */
export function createPersonaIdentityCheckConfig(
  inquiryId: string,
  bearerToken: string
): DecoConfig {
  return {
    secret_variables: [
      { name: "your_inquiry_id", value: inquiryId },
      { name: "your_bearer_auth", value: `Bearer ${bearerToken}` },
    ],
    public_variables: [
      { name: "persona_version", value: "2023-01-05" },
    ],
    request: {
      method: "GET",
      url: `https://withpersona.com/api/v1/inquiries/$[[your_inquiry_id]]`,
      headers: {
        "accept": "application/json",
        "content-type": "application/json",
        "Persona-Version": "${{persona_version}}",
        "authorization": "$[[your_bearer_auth]]",
      },
    },
    proof_spec: {
      // Assertions on private fields - these are verified but not revealed
      predicates: [
        {
          op: "equal",
          queries_for_scalars: ["body.data.attributes.status"],
          public_operands: ["completed"],
        },
        {
          op: "equal",
          queries_for_scalars: ["body.included[0].attributes.status"],
          public_operands: ["passed"],
        },
        {
          op: "equal",
          queries_for_scalars: ['body.included[0].attributes."country-code"'],
          public_operands: ["US"],
        },
      ],
      // Fields that are revealed to the verifier
      public_fields: [
        "headers",
        "body.included[0].type",
        'body.included[0].attributes."completed-at"',
      ],
      // Assertions on public fields - included in attestation
      assertions_on_public_data: [
        { script: "body.included[0].type" },
        { script: 'body.included[0].attributes."completed-at"' },
      ],
    },
  }
}

/**
 * The expected attestation result structure from DECO
 */
export interface DecoAttestationResult {
  success: boolean[]
  proof_specs: Array<{
    client: {
      request_spec: {
        method: string
        url: string
        headers: Record<string, string[]>
      }
    }
    server: {
      json_proof_spec: {
        predicates: DecoPredicate[]
        assertions_on_public_data: DecoAssertionOnPublicData[]
      }
    }
  }>
  public_outputs: string[]
  attestation: string // Base64 encoded attestation
  timestamp: string
}
