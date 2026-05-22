import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { fetchProjects, fetchTasks, fetchProfiles } from "@/lib/queries";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend } from "recharts";
import { FolderKanban, CheckCircle2, Clock, AlertTriangle, Users } from "lucide-react";
import { motion } from "framer-motion";

export const Route = createFileRoute("/_authenticated/dashboard")({ component: Dashboard });

const STATUS_COLORS: Record<string, string> = {
  todo: "oklch(0.68 0.03 260)",
  in_progress: "oklch(0.62 0.22 275)",
  review: "oklch(0.78 0.16 75)",
  done: "oklch(0.7 0.17 155)",
};

function Dashboard() {
  const projects = useQuery({ queryKey: ["projects"], queryFn: fetchProjects });
  const tasks = useQuery({ queryKey: ["tasks"], queryFn: () => fetchTasks() });
  const profiles = useQuery({ queryKey: ["profiles"], queryFn: fetchProfiles });

  if (projects.isLoading || tasks.isLoading) {
    return (
      <div className="grid gap-4 md:grid-cols-4">
        {[...Array(4)].map((_, i) => <Skeleton key={i} className="h-28" />)}
      </div>
    );
  }

  const t = tasks.data ?? [];
  const now = Date.now();
  const completed = t.filter((x) => x.status === "done").length;
  const pending = t.filter((x) => x.status !== "done").length;
  const overdue = t.filter((x) => x.due_date && new Date(x.due_date).getTime() < now && x.status !== "done").length;

  const statusData = ["todo", "in_progress", "review", "done"].map((s) => ({
    name: s.replace("_", " "),
    value: t.filter((x) => x.status === s).length,
    key: s,
  }));

  const memberProductivity = (profiles.data ?? []).map((p) => ({
    name: p.name.split(" ")[0] || p.email.split("@")[0],
    done: t.filter((x) => x.assigned_to === p.id && x.status === "done").length,
    open: t.filter((x) => x.assigned_to === p.id && x.status !== "done").length,
  })).filter((m) => m.done + m.open > 0).slice(0, 8);

  const stats = [
    { label: "Projects", value: projects.data?.length ?? 0, icon: FolderKanban, color: "text-primary-glow" },
    { label: "Completed", value: completed, icon: CheckCircle2, color: "text-success" },
    { label: "Pending", value: pending, icon: Clock, color: "text-warning" },
    { label: "Overdue", value: overdue, icon: AlertTriangle, color: "text-destructive" },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-3xl font-bold">Dashboard</h1>
        <p className="text-sm text-muted-foreground">Your workspace at a glance.</p>
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        {stats.map((s, i) => (
          <motion.div
            key={s.label}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.05 }}
          >
            <Card>
              <CardContent className="flex items-center justify-between p-6">
                <div>
                  <p className="text-xs uppercase tracking-widest text-muted-foreground">{s.label}</p>
                  <p className="mt-2 font-display text-3xl font-bold">{s.value}</p>
                </div>
                <s.icon className={`h-8 w-8 ${s.color}`} />
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader><CardTitle>Team productivity</CardTitle></CardHeader>
          <CardContent className="h-80">
            {memberProductivity.length === 0 ? (
              <EmptyState icon={Users} title="No assigned tasks yet" />
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={memberProductivity}>
                  <XAxis dataKey="name" stroke="oklch(0.68 0.03 260)" fontSize={12} />
                  <YAxis stroke="oklch(0.68 0.03 260)" fontSize={12} />
                  <Tooltip contentStyle={{ background: "oklch(0.18 0.035 270)", border: "1px solid oklch(0.27 0.04 270)", borderRadius: 8 }} />
                  <Legend />
                  <Bar dataKey="done" fill={STATUS_COLORS.done} radius={[4, 4, 0, 0]} />
                  <Bar dataKey="open" fill={STATUS_COLORS.in_progress} radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle>Task status</CardTitle></CardHeader>
          <CardContent className="h-80">
            {t.length === 0 ? (
              <EmptyState icon={CheckCircle2} title="No tasks yet" />
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={statusData} dataKey="value" nameKey="name" innerRadius={50} outerRadius={90} paddingAngle={3}>
                    {statusData.map((d) => <Cell key={d.key} fill={STATUS_COLORS[d.key]} />)}
                  </Pie>
                  <Tooltip contentStyle={{ background: "oklch(0.18 0.035 270)", border: "1px solid oklch(0.27 0.04 270)", borderRadius: 8 }} />
                </PieChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function EmptyState({ icon: Icon, title }: { icon: typeof Users; title: string }) {
  return (
    <div className="flex h-full flex-col items-center justify-center text-center">
      <Icon className="h-10 w-10 text-muted-foreground/50" />
      <p className="mt-3 text-sm text-muted-foreground">{title}</p>
    </div>
  );
}
