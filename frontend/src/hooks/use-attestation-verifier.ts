"use client";

import { useReadContract } from "wagmi";
import { CONTRACTS } from "@/lib/contracts";
import { AttestationVerifierABI } from "@/lib/abis";
import { TrustAttestationVerifierABI } from "@/lib/abis";

export function useVerifyAttestation(
  attestationId: `0x${string}` | undefined
) {
  return useReadContract({
    address: CONTRACTS.AttestationVerifier.proxy,
    abi: AttestationVerifierABI,
    functionName: "verifyAttestation",
    args: attestationId ? [attestationId] : undefined,
    query: { enabled: !!attestationId },
  });
}

export function useTrustVerifyAttestation(
  attestationId: `0x${string}` | undefined
) {
  return useReadContract({
    address: CONTRACTS.TrustAttestationVerifier.proxy,
    abi: TrustAttestationVerifierABI,
    functionName: "verifyAttestation",
    args: attestationId ? [attestationId] : undefined,
    query: { enabled: !!attestationId },
  });
}
