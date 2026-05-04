import { ButtonHTMLAttributes, ReactNode } from "react";

interface GhostButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
  className?: string;
}

export function GhostButton({
  children,
  className = "",
  ...rest
}: GhostButtonProps) {
  return (
    <button
      {...rest}
      className={`inline-flex items-center justify-center gap-2 rounded-pill border border-indigo-outline text-indigo-outline bg-transparent font-normal text-[15px] tracking-[-0.26px] py-2.5 px-6 transition-colors hover:bg-indigo-outline/5 ${className}`}
    >
      {children}
    </button>
  );
}

export default GhostButton;
