import { useQuery } from "@tanstack/react-query";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { listOrganizationUsers } from "@/features/users/api";

export function UsersPage() {
  const { data: users, isLoading, isError, error } = useQuery({
    queryKey: ["organization-users"],
    queryFn: listOrganizationUsers,
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-slate-900">Users</h1>
        <p className="text-sm text-slate-500">Staff within your organization and their assigned roles.</p>
      </div>

      <Card className="overflow-hidden">
        {isLoading && <p className="p-5 text-sm text-slate-500">Loading users…</p>}
        {isError && (
          <p className="p-5 text-sm text-fail">{error instanceof Error ? error.message : "Failed to load users"}</p>
        )}
        {users && (
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Name
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Email
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Roles
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Status
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {users.map((user) => (
                <tr key={user.id} className="hover:bg-slate-50">
                  <td className="px-5 py-3 text-sm font-medium text-slate-900">{user.full_name}</td>
                  <td className="px-5 py-3 text-sm text-slate-700">{user.email}</td>
                  <td className="px-5 py-3 text-sm">
                    <div className="flex flex-wrap gap-1">
                      {user.roles.length === 0 && <span className="text-slate-400">No role</span>}
                      {user.roles.map((r) => (
                        <Badge key={r.id} tone="info">
                          {r.role}
                        </Badge>
                      ))}
                    </div>
                  </td>
                  <td className="px-5 py-3 text-sm">
                    <Badge tone={user.is_active ? "pass" : "neutral"}>{user.is_active ? "Active" : "Inactive"}</Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}
