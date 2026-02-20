"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { cn } from "@/lib/utils";

const NAV_ITEMS = [
  { href: "/", label: "Dashboard" },
  { href: "/verify", label: "Verify Credential" },
  { href: "/explorer", label: "Explorer" },
  { href: "/docs", label: "Docs" },
];

export function Sidebar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <>
      {/* Mobile hamburger */}
      <button
        onClick={() => setOpen(true)}
        className="fixed top-4 left-4 z-50 md:hidden rounded-lg bg-card border border-border p-2 text-foreground"
        aria-label="Open menu"
      >
        <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
        </svg>
      </button>

      {/* Backdrop */}
      {open && (
        <div
          className="fixed inset-0 z-40 bg-black/50 md:hidden"
          onClick={() => setOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          "fixed left-0 top-0 z-50 flex h-screen w-60 flex-col border-r border-border bg-card transition-transform duration-200",
          open ? "translate-x-0" : "-translate-x-full md:translate-x-0"
        )}
      >
        <div className="flex items-center justify-between border-b border-border">
          <Link
            href="/"
            onClick={() => setOpen(false)}
            className="flex h-16 flex-1 items-center gap-2 px-4 hover:bg-muted/50 transition-colors"
          >
            <div className="flex h-8 w-8 items-center justify-center rounded-md bg-accent text-accent-foreground text-sm font-bold">
              TLH
            </div>
            <div>
              <div className="text-sm font-semibold text-foreground">
                Trust Layer Health
              </div>
              <div className="text-xs text-muted-foreground">Sepolia Testnet</div>
            </div>
          </Link>
          <button
            onClick={() => setOpen(false)}
            className="md:hidden p-2 mr-2 text-muted-foreground hover:text-foreground"
            aria-label="Close menu"
          >
            <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <nav className="flex-1 space-y-1 px-2 py-4">
          {NAV_ITEMS.map((item) => {
            const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setOpen(false)}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors",
                  active
                    ? "bg-accent/10 text-accent font-medium"
                    : "text-muted-foreground hover:bg-muted hover:text-foreground"
                )}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="border-t border-border p-4">
          <div className="flex items-center gap-2" title="Connected network for shared anchor contracts">
            <div className="h-2 w-2 rounded-full bg-accent" />
            <span className="text-xs text-muted-foreground">
              Sepolia (Chain 11155111)
            </span>
          </div>
          <div className="flex items-center gap-2 mt-2" title="Private trust chain (local Polygon Edge)">
            <div className="h-2 w-2 rounded-full bg-muted-foreground" />
            <span className="text-xs text-muted-foreground">
              Private (Chain 100100)
            </span>
          </div>
        </div>
      </aside>
    </>
  );
}
