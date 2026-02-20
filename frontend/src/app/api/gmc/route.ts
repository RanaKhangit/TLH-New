/**
 * API Route: GET /api/gmc
 *
 * Proxies GMC lookup requests to the Prover API with:
 * - Server-side authentication (API token not exposed to browser)
 * - Input validation
 */

import { NextRequest, NextResponse } from "next/server"

const PROVER_API_URL = process.env.PROVER_API_URL || "http://localhost:8787"
const PROVER_API_TOKEN = process.env.PROVER_API_TOKEN || ""

// Simple name validation regex
const NAME_REGEX = /^[a-zA-Z\s\-']+$/

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const surname = searchParams.get("surname")
    const givenName = searchParams.get("givenName")

    // Validate inputs
    if (!surname || !givenName) {
      return NextResponse.json(
        { error: "surname and givenName are required" },
        { status: 400 }
      )
    }

    if (surname.length > 100 || givenName.length > 100) {
      return NextResponse.json(
        { error: "Name parameters too long" },
        { status: 400 }
      )
    }

    if (!NAME_REGEX.test(surname) || !NAME_REGEX.test(givenName)) {
      return NextResponse.json(
        { error: "Invalid characters in name parameters" },
        { status: 400 }
      )
    }

    const headers: HeadersInit = {
      "Content-Type": "application/json",
    }

    if (PROVER_API_TOKEN) {
      headers["Authorization"] = `Bearer ${PROVER_API_TOKEN}`
    }

    const params = new URLSearchParams({ surname, givenName })
    const response = await fetch(`${PROVER_API_URL}/gmc/lookup?${params}`, {
      method: "GET",
      headers,
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      return NextResponse.json(
        { error: errorData.error || `GMC lookup failed: ${response.status}` },
        { status: response.status }
      )
    }

    const data = await response.json()
    return NextResponse.json(data)
  } catch (error) {
    console.error("[API/gmc] Error:", error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "GMC lookup failed" },
      { status: 500 }
    )
  }
}
