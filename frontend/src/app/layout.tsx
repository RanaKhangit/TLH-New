import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Providers } from "./providers";
import { Sidebar } from "@/components/layout/sidebar";
import { ErrorBoundary } from "@/components/ui/error-boundary";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Trust Layer Health — Demo",
  description:
    "Clinician credential verification on Ethereum Sepolia via Chainlink DECO",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        <Providers>
          <a
            href="#main-content"
            className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:rounded-lg focus:bg-accent focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:text-accent-foreground"
          >
            Skip to main content
          </a>
          <Sidebar />
          <div className="ml-60 flex min-h-screen flex-col">
            <main id="main-content" className="flex-1 p-8">
              <ErrorBoundary>{children}</ErrorBoundary>
            </main>
            <footer className="border-t border-border px-8 py-4">
              <p className="text-xs text-muted-foreground">
                Trust Layer Health — Sepolia Testnet Demo
              </p>
            </footer>
          </div>
        </Providers>
      </body>
    </html>
  );
}
