import { forwardRef, type InputHTMLAttributes, type LabelHTMLAttributes } from "react";
import { cn } from "@/utils/cn";

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        "block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:border-navy focus:outline-none focus:ring-1 focus:ring-navy disabled:bg-slate-50 disabled:text-slate-500",
        className,
      )}
      {...props}
    />
  ),
);
Input.displayName = "Input";

export function Label({ className, ...props }: LabelHTMLAttributes<HTMLLabelElement>) {
  return <label className={cn("mb-1 block text-sm font-medium text-slate-700", className)} {...props} />;
}
