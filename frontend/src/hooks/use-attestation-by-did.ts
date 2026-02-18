"use client";

import { useReadContract } from "wagmi";
import { CONTRACTS } from "@/lib/contracts";
import { AttestationVerifierABI } from "@/lib/abis";

/**
 * Look up an attestation by its ID on Sepolia AttestationVerifier
 */
export function useGetAttestation(attestationId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.AttestationVerifier.proxy,
    abi: AttestationVerifierABI,
    functionName: "verifyAttestation",
    args: attestationId ? [attestationId] : undefined,
    query: {
      enabled: !!attestationId,
    },
  });
}
