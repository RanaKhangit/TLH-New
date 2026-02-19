"use client";

import { useReadContracts } from "wagmi";
import { CONTRACTS, PRIVATE_CHAIN_CONTRACTS } from "@/lib/contracts";
import {
  DIDRegistryABI,
  AttestationVerifierABI,
  VCHashAnchorsABI,
  CredentialRegistryABI,
  TrustAttestationVerifierABI,
} from "@/lib/abis";
import { privateChain } from "@/lib/wagmi";

const ZERO_ROLE =
  "0x0000000000000000000000000000000000000000000000000000000000000000" as const;
const ZERO_ADDR = "0x0000000000000000000000000000000000000000" as const;

export function useContractHealth() {
  // Sepolia shared anchor contracts
  const sepoliaResult = useReadContracts({
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
    ],
    query: { refetchInterval: 30000 },
  });

  // Private chain trust contracts
  const privateResult = useReadContracts({
    contracts: [
      {
        address: PRIVATE_CHAIN_CONTRACTS.CredentialRegistry.proxy,
        abi: CredentialRegistryABI,
        functionName: "hasRole",
        args: [ZERO_ROLE, ZERO_ADDR],
        chainId: privateChain.id,
      },
      {
        address: PRIVATE_CHAIN_CONTRACTS.TrustAttestationVerifier.proxy,
        abi: TrustAttestationVerifierABI,
        functionName: "hasRole",
        args: [ZERO_ROLE, ZERO_ADDR],
        chainId: privateChain.id,
      },
    ],
    query: { refetchInterval: 30000, retry: 1 },
  });

  const sepoliaNames = [
    "DIDRegistry",
    "AttestationVerifier",
    "VCHashAnchors",
  ] as const;

  const sepoliaContracts = sepoliaNames.map((name, i) => ({
    name,
    address: CONTRACTS[name].proxy,
    chain: "sepolia" as const,
    responsive: sepoliaResult.data?.[i]?.status === "success",
  }));

  const privateNames = [
    "CredentialRegistry",
    "TrustAttestationVerifier",
  ] as const;

  const privateContracts = privateNames.map((name, i) => ({
    name,
    address: PRIVATE_CHAIN_CONTRACTS[name].proxy,
    chain: "private" as const,
    responsive: privateResult.data?.[i]?.status === "success",
  }));

  return {
    sepoliaContracts,
    privateContracts,
    contracts: [...sepoliaContracts, ...privateContracts],
    isLoading: sepoliaResult.isLoading,
    privateChainOffline: privateResult.isError || !privateResult.data,
    error: sepoliaResult.error,
  };
}
