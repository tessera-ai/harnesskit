import { HTMLAttributes, ReactNode } from "react";

interface SoftCardProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  className?: string;
}

export function SoftCard({ children, className = "", ...rest }: SoftCardProps) {
  return (
    <div
      {...rest}
      className={`bg-soft-card rounded-card shadow-soft p-5 ${className}`}
    >
      {children}
    </div>
  );
}

export default SoftCard;
