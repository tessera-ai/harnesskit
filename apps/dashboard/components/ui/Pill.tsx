import { HTMLAttributes, ReactNode } from "react";

type PillVariant = "outline" | "filled" | "subtle";

interface PillProps extends HTMLAttributes<HTMLSpanElement> {
  children: ReactNode;
  variant?: PillVariant;
  className?: string;
}

const variantClasses: Record<PillVariant, string> = {
  outline:
    "border border-indigo-outline text-indigo-outline bg-transparent",
  filled: "bg-luminescent-violet text-white border border-transparent",
  subtle: "bg-ash text-graphite border border-transparent",
};

export function Pill({
  children,
  variant = "outline",
  className = "",
  ...rest
}: PillProps) {
  return (
    <span
      {...rest}
      className={`inline-flex items-center gap-1.5 rounded-pill px-3 py-1 text-[13px] tracking-[-0.21px] leading-none font-normal ${variantClasses[variant]} ${className}`}
    >
      {children}
    </span>
  );
}

export default Pill;
