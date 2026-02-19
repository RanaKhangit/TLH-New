"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const NAV_ITEMS = [
  { href: "/", label: "Dashboard" },
  { href: "/verify", label: "Verify Credential" },
  { href: "/explorer", label: "Explorer" },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="fixed left-0 top-0 z-40 flex h-screen w-60 flex-col border-r border-border bg-card">
      <Link href="/" className="flex h-16 items-center gap-2 border-b border-border px-4 hover:bg-muted/50 transition-colors">
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

      <nav className="flex-1 space-y-1 px-2 py-4">
        {NAV_ITEMS.map((item) => {
          const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
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
  );
}
