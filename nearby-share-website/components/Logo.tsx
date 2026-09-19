export default function Logo({ size = 32 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <rect width="64" height="64" rx="16" fill="#2557FF" />
      <path
        d="M15 29a24 24 0 0 1 34 0M22 36a14 14 0 0 1 20 0"
        fill="none"
        stroke="#fff"
        strokeWidth="4.5"
        strokeLinecap="round"
      />
      <circle cx="32" cy="45" r="4" fill="#FFC24B" />
    </svg>
  );
}
