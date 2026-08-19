import { NavLink } from "react-router-dom";
import { LayoutDashboard, Wrench, Layers, Users, Settings } from "lucide-react";
import { cn } from "@/utils/cn";

const navItems = [
  { to: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { to: "/cycles", label: "Cycles", icon: Layers },
  { to: "/equipment", label: "Equipment", icon: Wrench },
  { to: "/users", label: "Users", icon: Users },
  { to: "/settings", label: "Settings", icon: Settings },
];

export function Sidebar() {
  return (
    <aside className="flex h-full w-60 shrink-0 flex-col bg-navy text-white">
      <div className="flex items-center gap-2 px-5 py-5">
        <div className="flex h-8 w-8 items-center justify-center rounded-md bg-teal font-bold">S</div>
        <span className="text-lg font-semibold tracking-tight">SteriCord</span>
      </div>
      <nav className="flex-1 space-y-1 px-3">
        {navItems.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-slate-200 transition-colors hover:bg-navy-light hover:text-white",
                isActive && "bg-navy-light text-white",
              )
            }
          >
            <Icon size={18} />
            {label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
