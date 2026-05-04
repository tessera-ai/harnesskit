import {
  Activity,
  ClipboardList,
  Wrench,
  Bot,
  Settings,
  LucideIcon,
} from "lucide-react";

interface NavItem {
  label: string;
  Icon: LucideIcon;
  active?: boolean;
}

const items: NavItem[] = [
  { label: "Traces", Icon: Activity, active: true },
  { label: "Evals", Icon: ClipboardList },
  { label: "Tools", Icon: Wrench },
  { label: "Agents", Icon: Bot },
  { label: "Settings", Icon: Settings },
];

export function Sidebar() {
  return (
    <aside className="w-56 shrink-0 px-4 py-6">
      <nav className="flex flex-col gap-1">
        {items.map(({ label, Icon, active }) => (
          <a
            key={label}
            href="#"
            className={`group flex items-center gap-3 rounded-default px-3 py-2.5 text-[15px] tracking-[-0.26px] transition-colors ${
              active
                ? "text-graphite font-medium"
                : "text-slate-muted hover:text-graphite"
            }`}
          >
            <span
              className={`flex h-7 w-7 items-center justify-center rounded-default ${
                active
                  ? "bg-luminescent-violet/12 text-luminescent-violet"
                  : "text-slate-muted group-hover:text-graphite"
              }`}
            >
              <Icon size={16} strokeWidth={1.75} />
            </span>
            <span>{label}</span>
          </a>
        ))}
      </nav>
    </aside>
  );
}

export default Sidebar;
