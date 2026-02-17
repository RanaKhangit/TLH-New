"use client";

import { useReadContract } from "wagmi";
import { CONTRACTS } from "@/lib/contracts";
import { VCHashAnchorsABI } from "@/lib/abis";

export function useGetAnchor(
  subjectDID: `0x${string}` | undefined,
  vcType: `0x${string}` | undefined
) {
  return useReadContract({
    address: CONTRACTS.VCHashAnchors.proxy,
    abi: VCHashAnchorsABI,
    functionName: "getAnchor",
    args: subjectDID && vcType ? [subjectDID, vcType] : undefined,
    query: { enabled: !!subjectDID && !!vcType },
  });
}

export function useGetAnchorHistory(
  subjectDID: `0x${string}` | undefined,
  vcType: `0x${string}` | undefined
) {
  return useReadContract({
    address: CONTRACTS.VCHashAnchors.proxy,
    abi: VCHashAnchorsABI,
    functionName: "getAnchorHistory",
    args: subjectDID && vcType ? [subjectDID, vcType] : undefined,
    query: { enabled: !!subjectDID && !!vcType },
  });
}
