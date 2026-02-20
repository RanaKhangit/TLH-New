"use client";

import { useReadContract } from "wagmi";
import { CONTRACTS } from "@/lib/contracts";
import { DIDRegistryABI } from "@/lib/abis";

export function useResolveDID(did: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.DIDRegistry.proxy,
    abi: DIDRegistryABI,
    functionName: "resolveDID",
    args: did ? [did] : undefined,
    query: {
      enabled: !!did,
      retry: 2,
      retryDelay: 1000,
      staleTime: 30_000, // Cache results for 30 seconds
      gcTime: 60_000, // Keep in cache for 1 minute
    },
  });
}
