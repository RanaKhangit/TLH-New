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
    query: { enabled: !!did },
  });
}

export function useLastUpdatedAt() {
  return useReadContract({
    address: CONTRACTS.DIDRegistry.proxy,
    abi: DIDRegistryABI,
    functionName: "lastUpdatedAt",
  });
}
