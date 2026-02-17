export function Skeleton({ className = "" }: { className?: string }) {
  return (
    <div className={`bg-muted rounded animate-pulse ${className}`} />
  );
}
