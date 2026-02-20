const VARIANT_COLORS = {
  success: "bg-success/10 text-success border-success/20",
  danger: "bg-danger/10 text-danger border-danger/20",
  warning: "bg-warning/10 text-warning border-warning/20",
  muted: "bg-muted text-muted-foreground border-border",
} as const;

export type BadgeVariant = keyof typeof VARIANT_COLORS;

export function Badge({
  variant,
  children,
}: {
  variant: BadgeVariant;
  children: React.ReactNode;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-md border px-2.5 py-0.5 text-xs font-medium ${VARIANT_COLORS[variant]}`}
    >
      {children}
    </span>
  );
}
