"use client";

import { useReadContract } from "wagmi";
import { CONTRACTS } from "@/lib/contracts";
import { CredentialRegistryABI } from "@/lib/abis";

export function useGetCredential(
  subjectDID: `0x${string}` | undefined,
  predicateType: `0x${string}` | undefined
) {
  return useReadContract({
    address: CONTRACTS.CredentialRegistry.proxy,
    abi: CredentialRegistryABI,
    functionName: "getCredential",
    args:
      subjectDID && predicateType ? [subjectDID, predicateType] : undefined,
    query: { enabled: !!subjectDID && !!predicateType },
  });
}

export function useIsCredentialValid(
  subjectDID: `0x${string}` | undefined,
  predicateType: `0x${string}` | undefined
) {
  return useReadContract({
    address: CONTRACTS.CredentialRegistry.proxy,
    abi: CredentialRegistryABI,
    functionName: "isCredentialValid",
    args:
      subjectDID && predicateType ? [subjectDID, predicateType] : undefined,
    query: { enabled: !!subjectDID && !!predicateType },
  });
}
