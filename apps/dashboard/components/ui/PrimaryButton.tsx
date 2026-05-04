import { ButtonHTMLAttributes, ReactNode } from "react";

interface PrimaryButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
  className?: string;
}

export function PrimaryButton({
  children,
  className = "",
  ...rest
}: PrimaryButtonProps) {
  return (
    <button
      {...rest}
      className={`inline-flex items-center justify-center gap-2 rounded-pill bg-luminescent-violet text-white font-medium text-[15px] tracking-[-0.26px] py-2.5 px-6 transition-opacity hover:opacity-90 ${className}`}
    >
      {children}
    </button>
  );
}

export default PrimaryButton;
