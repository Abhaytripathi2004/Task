import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { fetchProfiles, fetchRoles, fetchTasks } from "@/lib/queries";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

export const Route = createFileRoute("/_authenticated/team")({ component: Team });

function Team() {
  const profiles = useQuery({ queryKey: ["profiles"], queryFn: fetchProfiles });
  const roles = useQuery({ queryKey: ["roles"], queryFn: fetchRoles });
  const tasks = useQuery({ queryKey: ["tasks"], queryFn: () => fetchTasks() });

  if (profiles.isLoading) {
    return <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">{[...Array(6)].map((_, i) => <Skeleton key={i} className="h-32" />)}</div>;
  }

  const roleMap = new Map<string, string>();
  (roles.data ?? []).forEach((r) => roleMap.set(r.user_id, r.role));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-3xl font-bold">Team</h1>
        <p className="text-sm text-muted-foreground">{profiles.data?.length ?? 0} members</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {(profiles.data ?? []).map((p) => {
          const role = roleMap.get(p.id) ?? "member";
          const myTasks = (tasks.data ?? []).filter((t) => t.assigned_to === p.id);
          const done = myTasks.filter((t) => t.status === "done").length;
          return (
            <Card key={p.id}>
              <CardContent className="p-6">
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-[image:var(--gradient-primary)] text-base font-semibold uppercase text-primary-foreground">
                    {(p.name || p.email)[0]}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium">{p.name || p.email.split("@")[0]}</p>
                    <p className="truncate text-xs text-muted-foreground">{p.email}</p>
                  </div>
                  <Badge variant={role === "admin" ? "default" : "outline"} className="capitalize">{role}</Badge>
                </div>
                <div className="mt-5 grid grid-cols-2 gap-2 text-center text-xs">
                  <div className="rounded-lg bg-muted p-2">
                    <div className="font-display text-lg font-bold">{myTasks.length}</div>
                    <div className="text-muted-foreground">Assigned</div>
                  </div>
                  <div className="rounded-lg bg-muted p-2">
                    <div className="font-display text-lg font-bold text-success">{done}</div>
                    <div className="text-muted-foreground">Completed</div>
                  </div>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
