type Props = {
  /** "line" draws a thin rule either side of the heart; "plain" is just the heart. */
  variant?: "line" | "plain";
  className?: string;
};

function Heart({ className = "" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      className={`h-3.5 w-3.5 shrink-0 ${className}`}
      fill="currentColor"
    >
      <path d="M12 21s-6.7-4.35-9.33-8.24C.9 9.9 2.02 6.2 5.2 5.2c2-.63 4.02.2 5.1 1.86l1.7 2.6 1.7-2.6c1.08-1.66 3.1-2.49 5.1-1.86 3.18 1 4.3 4.7 2.53 7.56C18.7 16.65 12 21 12 21z" />
    </svg>
  );
}

export default function HeartDivider({ variant = "line", className = "" }: Props) {
  if (variant === "plain") {
    return (
      <div className={`flex justify-center py-3 ${className}`}>
        <Heart className="text-rose heart-pulse" />
      </div>
    );
  }
  return (
    <div className={`flex items-center justify-center gap-3 py-3 text-rose/70 ${className}`}>
      <span className="h-px w-10 bg-current sm:w-16" />
      <Heart className="text-rose heart-pulse" />
      <span className="h-px w-10 bg-current sm:w-16" />
    </div>
  );
}
