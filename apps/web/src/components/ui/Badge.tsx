import type { HTMLAttributes } from "react";
import { cn } from "@/utils/cn";

type Tone = "neutral" | "pass" | "warning" | "fail" | "info";

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  tone?: Tone;
}

const toneClasses: Record<Tone, string> = {
  neutral: "bg-slate-100 text-slate-700",
  pass: "bg-emerald-100 text-emerald-800",
  warning: "bg-amber-100 text-amber-800",
  fail: "bg-red-100 text-red-800",
  info: "bg-sc-blue-light text-sc-blue",
};

export function Badge({ className, tone = "neutral", ...props }: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
        toneClasses[tone],
        className,
      )}
      {...props}
    />
  );
}
