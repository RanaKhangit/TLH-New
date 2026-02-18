"use client";

import { useReadContract } from "wagmi";
import { CONTRACTS, PRIVATE_CHAIN_CONTRACTS } from "@/lib/contracts";
import { AttestationVerifierABI, TrustAttestationVerifierABI } from "@/lib/abis";
import { privateChain } from "@/lib/wagmi";

/** Shared anchor AttestationVerifier — queries Sepolia */
export function useVerifyAttestation(
  attestationId: `0x${string}` | undefined
) {
  return useReadContract({
    address: CONTRACTS.AttestationVerifier.proxy,
    abi: AttestationVerifierABI,
    functionName: "verifyAttestation",
    args: attestationId ? [attestationId] : undefined,
    query: {
      enabled: !!attestationId,
      refetchInterval: (query) => {
        // Poll every 4s until attestation appears on-chain, then stop
        const data = query.state.data as readonly [boolean, ...unknown[]] | undefined;
        return data?.[0] ? false : 4000;
      },
    },
  });
}

/** Trust TrustAttestationVerifier — queries Private Chain (100100) */
export function useTrustVerifyAttestation(
  attestationId: `0x${string}` | undefined
) {
  return useReadContract({
    address: PRIVATE_CHAIN_CONTRACTS.TrustAttestationVerifier.proxy,
    abi: TrustAttestationVerifierABI,
    functionName: "verifyAttestation",
    args: attestationId ? [attestationId] : undefined,
    chainId: privateChain.id,
    query: {
      enabled: !!attestationId,
      refetchInterval: (query) => {
        const data = query.state.data as readonly [boolean, ...unknown[]] | undefined;
        return data?.[0] ? false : 4000;
      },
    },
  });
}
