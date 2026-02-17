import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { keccak256, toHex } from "viem";
import { format, formatDistanceToNow } from "date-fns";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatTimestamp(ts: bigint): string {
  if (ts === 0n) return "Never";
  const date = new Date(Number(ts) * 1000);
  return format(date, "yyyy-MM-dd HH:mm:ss");
}

export function formatTimestampRelative(ts: bigint): string {
  if (ts === 0n) return "Never";
  const date = new Date(Number(ts) * 1000);
  return formatDistanceToNow(date, { addSuffix: true });
}

export function formatAddress(addr: string): string {
  if (!addr || addr.length < 10) return addr;
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export function formatBytes32(b: string): string {
  if (!b || b.length < 10) return b;
  return `${b.slice(0, 10)}...${b.slice(-6)}`;
}

export function toBytes32(str: string): `0x${string}` {
  return keccak256(toHex(str));
}

export function etherscanTxUrl(hash: string): string {
  return `https://sepolia.etherscan.io/tx/${hash}`;
}

export function etherscanAddressUrl(addr: string): string {
  return `https://sepolia.etherscan.io/address/${addr}`;
}

export function isValidBytes32(value: string): boolean {
  return /^0x[0-9a-fA-F]{64}$/.test(value);
}

export const CREDENTIAL_STATUS = {
  0: "Active",
  1: "Expired",
  2: "Revoked",
} as const;

export function credentialStatusLabel(status: number): string {
  return CREDENTIAL_STATUS[status as keyof typeof CREDENTIAL_STATUS] ?? "Unknown";
}
