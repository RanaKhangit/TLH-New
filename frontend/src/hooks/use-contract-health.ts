"use client";

import { useReadContracts } from "wagmi";
import { CONTRACTS } from "@/lib/contracts";
import { DIDRegistryABI } from "@/lib/abis";
import { AttestationVerifierABI } from "@/lib/abis";
import { VCHashAnchorsABI } from "@/lib/abis";
import { CredentialRegistryABI } from "@/lib/abis";
import { TrustAttestationVerifierABI } from "@/lib/abis";

const ZERO_ROLE =
  "0x0000000000000000000000000000000000000000000000000000000000000000" as const;
const ZERO_ADDR = "0x0000000000000000000000000000000000000000" as const;

export function useContractHealth() {
  const result = useReadContracts({
    contracts: [
      {
        address: CONTRACTS.DIDRegistry.proxy,
        abi: DIDRegistryABI,
        functionName: "hasRole",
        args: [ZERO_ROLE, ZERO_ADDR],
      },
      {
        address: CONTRACTS.AttestationVerifier.proxy,
        abi: AttestationVerifierABI,
        functionName: "hasRole",
        args: [ZERO_ROLE, ZERO_ADDR],
      },
      {
        address: CONTRACTS.VCHashAnchors.proxy,
        abi: VCHashAnchorsABI,
        functionName: "hasRole",
        args: [ZERO_ROLE, ZERO_ADDR],
      },
      {
        address: CONTRACTS.CredentialRegistry.proxy,
        abi: CredentialRegistryABI,
        functionName: "hasRole",
        args: [ZERO_ROLE, ZERO_ADDR],
      },
      {
        address: CONTRACTS.TrustAttestationVerifier.proxy,
        abi: TrustAttestationVerifierABI,
        functionName: "hasRole",
        args: [ZERO_ROLE, ZERO_ADDR],
      },
    ],
    query: { refetchInterval: 30000 },
  });

  const names = [
    "DIDRegistry",
    "AttestationVerifier",
    "VCHashAnchors",
    "CredentialRegistry",
    "TrustAttestationVerifier",
  ] as const;

  const contracts = names.map((name, i) => ({
    name,
    address: CONTRACTS[name].proxy,
    responsive: result.data?.[i]?.status === "success",
  }));

  return {
    contracts,
    isLoading: result.isLoading,
    error: result.error,
  };
}
