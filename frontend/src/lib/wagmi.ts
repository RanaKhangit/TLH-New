import { http, createConfig } from "wagmi";
import { sepolia } from "wagmi/chains";
import { defineChain } from "viem";

const sepoliaRpc =
  process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL ||
  "https://ethereum-sepolia-rpc.publicnode.com";

const privateChainRpc =
  process.env.NEXT_PUBLIC_PRIVATE_CHAIN_RPC_URL || "http://localhost:8545";

export const privateChain = defineChain({
  id: 100100,
  name: "TLH Private Chain",
  nativeCurrency: { name: "ETH", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: [privateChainRpc] },
  },
});

export const config = createConfig({
  chains: [sepolia, privateChain],
  transports: {
    [sepolia.id]: http(sepoliaRpc),
    [privateChain.id]: http(privateChainRpc),
  },
  ssr: true,
});
