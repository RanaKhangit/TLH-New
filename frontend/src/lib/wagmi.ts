import { http, createConfig, fallback } from "wagmi";
import { sepolia } from "wagmi/chains";
import { defineChain } from "viem";

// Sepolia RPC with fallbacks - all CORS-friendly public endpoints
const SEPOLIA_RPCS = [
  "https://sepolia.drpc.org",
  "https://ethereum-sepolia-rpc.publicnode.com",
  "https://rpc.sepolia.org",
  "https://sepolia.gateway.tenderly.co",
];

const sepoliaRpc = process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL || SEPOLIA_RPCS[0];

const privateChainRpc =
  process.env.NEXT_PUBLIC_PRIVATE_CHAIN_RPC_URL || "http://localhost:8545";

// RPC timeout in milliseconds - increased for browser environments
const RPC_TIMEOUT = 20_000;

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
    [sepolia.id]: fallback([
      http(sepoliaRpc, { timeout: RPC_TIMEOUT, retryCount: 2, retryDelay: 500 }),
      http(SEPOLIA_RPCS[1], { timeout: RPC_TIMEOUT, retryCount: 2, retryDelay: 500 }),
      http(SEPOLIA_RPCS[2], { timeout: RPC_TIMEOUT, retryCount: 2, retryDelay: 500 }),
      http(SEPOLIA_RPCS[3], { timeout: RPC_TIMEOUT, retryCount: 2, retryDelay: 500 }),
    ]),
    [privateChain.id]: http(privateChainRpc, {
      timeout: RPC_TIMEOUT,
      retryCount: 2,
      retryDelay: 1000,
    }),
  },
  ssr: true,
});
