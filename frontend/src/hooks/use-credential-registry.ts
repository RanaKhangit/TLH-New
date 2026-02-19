"use client";

import { useReadContract } from "wagmi";
import { PRIVATE_CHAIN_CONTRACTS } from "@/lib/contracts";
import { CredentialRegistryABI } from "@/lib/abis";
import { privateChain } from "@/lib/wagmi";

/** Queries CredentialRegistry on Private Chain (100100) — this is the trust chain */
export function useGetCredential(
  subjectDID: `0x${string}` | undefined,
  predicateType: `0x${string}` | undefined
) {
  return useReadContract({
    address: PRIVATE_CHAIN_CONTRACTS.CredentialRegistry.proxy,
    abi: CredentialRegistryABI,
    functionName: "getCredential",
    args:
      subjectDID && predicateType ? [subjectDID, predicateType] : undefined,
    chainId: privateChain.id,
    query: {
      enabled: !!subjectDID && !!predicateType,
      refetchInterval: (query) => {
        // Poll every 4s until credential appears on-chain, then stop
        const data = query.state.data as boolean | undefined;
        return data ? false : 4000;
      },
    },
  });
}

export function useIsCredentialValid(
  subjectDID: `0x${string}` | undefined,
  predicateType: `0x${string}` | undefined
) {
  return useReadContract({
    address: PRIVATE_CHAIN_CONTRACTS.CredentialRegistry.proxy,
    abi: CredentialRegistryABI,
    functionName: "isCredentialValid",
    args:
      subjectDID && predicateType ? [subjectDID, predicateType] : undefined,
    chainId: privateChain.id,
    query: {
      enabled: !!subjectDID && !!predicateType,
      refetchInterval: (query) => {
        // Poll every 4s until credential is confirmed valid, then stop
        const data = query.state.data as boolean | undefined;
        return data ? false : 4000;
      },
    },
  });
}
