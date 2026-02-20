/**
 * API Route: GET /api/verify
 *
 * Proxies verification requests to the Prover API with:
 * - Server-side authentication (API token not exposed to browser)
 * - CSRF protection via same-origin policy
 */

import { NextRequest, NextResponse } from "next/server"

const PROVER_API_URL = process.env.PROVER_API_URL || "http://localhost:8787"
const PROVER_API_TOKEN = process.env.PROVER_API_TOKEN || ""

export async function GET(request: NextRequest) {
  // CSRF protection: Verify request is from same origin
  const origin = request.headers.get("origin")
  const host = request.headers.get("host")

  if (origin && host && !origin.includes(host.split(":")[0])) {
    return NextResponse.json(
      { error: "Cross-origin requests not allowed" },
      { status: 403 }
    )
  }

  try {
    const headers: HeadersInit = {
      "Content-Type": "application/json",
    }

    if (PROVER_API_TOKEN) {
      headers["Authorization"] = `Bearer ${PROVER_API_TOKEN}`
    }

    const response = await fetch(`${PROVER_API_URL}/deco/verify`, {
      method: "GET",
      headers,
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      return NextResponse.json(
        { error: errorData.error || `Prover API returned ${response.status}` },
        { status: response.status }
      )
    }

    const data = await response.json()
    return NextResponse.json(data)
  } catch (error) {
    console.error("[API/verify] Error:", error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Verification failed" },
      { status: 500 }
    )
  }
}

/**
 * POST /api/verify
 * For POST-based verification with custom attestation data
 */
export async function POST(request: NextRequest) {
  const origin = request.headers.get("origin")
  const host = request.headers.get("host")

  if (origin && host && !origin.includes(host.split(":")[0])) {
    return NextResponse.json(
      { error: "Cross-origin requests not allowed" },
      { status: 403 }
    )
  }

  try {
    const body = await request.json()

    const headers: HeadersInit = {
      "Content-Type": "application/json",
    }

    if (PROVER_API_TOKEN) {
      headers["Authorization"] = `Bearer ${PROVER_API_TOKEN}`
    }

    const response = await fetch(`${PROVER_API_URL}/deco/verify`, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      return NextResponse.json(
        { error: errorData.error || `Prover API returned ${response.status}` },
        { status: response.status }
      )
    }

    const data = await response.json()
    return NextResponse.json(data)
  } catch (error) {
    console.error("[API/verify] POST Error:", error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Verification failed" },
      { status: 500 }
    )
  }
}
