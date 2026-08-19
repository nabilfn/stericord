import { forwardRef, type ButtonHTMLAttributes } from "react";
import { cn } from "@/utils/cn";

type Variant = "primary" | "secondary" | "ghost" | "danger";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
}

const variantClasses: Record<Variant, string> = {
  primary: "bg-navy text-white hover:bg-navy-light focus-visible:outline-navy",
  secondary: "bg-white text-navy border border-slate-300 hover:bg-slate-50 focus-visible:outline-navy",
  ghost: "bg-transparent text-slate-700 hover:bg-slate-100 focus-visible:outline-slate-400",
  danger: "bg-fail text-white hover:bg-red-700 focus-visible:outline-fail",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "primary", ...props }, ref) => (
    <button
      ref={ref}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-md px-4 py-2 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
        variantClasses[variant],
        className,
      )}
      {...props}
    />
  ),
);
Button.displayName = "Button";
