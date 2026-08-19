import { forwardRef, type SelectHTMLAttributes } from "react";
import { cn } from "@/utils/cn";

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  ({ className, ...props }, ref) => (
    <select
      ref={ref}
      className={cn(
        "block w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:border-navy focus:outline-none focus:ring-1 focus:ring-navy",
        className,
      )}
      {...props}
    />
  ),
);
Select.displayName = "Select";
