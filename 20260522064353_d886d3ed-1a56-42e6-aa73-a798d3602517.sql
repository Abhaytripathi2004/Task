import { createFileRoute, Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth-context";
import { fetchTasks, fetchProjects, fetchProfiles } from "@/lib/queries";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Search, CheckSquare, Calendar, Plus } from "lucide-react";
import { toast } from "sonner";

export const Route = createFileRoute("/_authenticated/tasks")({ component: Tasks });

const PRIORITY_COLOR: Record<string, string> = {
  low: "text-muted-foreground",
  medium: "text-primary-glow",
  high: "text-warning",
  urgent: "text-destructive",
};

const taskSchema = z.object({
  project_id: z.string().uuid("Select a project"),
  title: z.string().trim().min(1, "Title is required").max(160),
  description: z.string().max(2000).optional(),
  priority: z.enum(["low", "medium", "high", "urgent"]),
  due_date: z.string().optional(),
  assigned_to: z.string().optional(),
});

function Tasks() {
  const { user, role } = useAuth();
  const qc = useQueryClient();
  const tasks = useQuery({ queryKey: ["tasks"], queryFn: () => fetchTasks() });
  const projects = useQuery({ queryKey: ["projects"], queryFn: fetchProjects });
  const profiles = useQuery({ queryKey: ["profiles"], queryFn: fetchProfiles });
  const [search, setSearch] = useState("");
  const [scope, setScope] = useState<"all" | "mine">("mine");
  const [status, setStatus] = useState("all");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ project_id: "", title: "", description: "", priority: "medium" as "low" | "medium" | "high" | "urgent", due_date: "", assigned_to: "" });

  const update = useMutation({
    mutationFn: async ({ id, status }: { id: string; status: "todo" | "in_progress" | "review" | "done" }) => {
      const { error } = await supabase.from("tasks").update({ status }).eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
    onError: (e: Error) => toast.error(e.message),
  });

  const create = useMutation({
    mutationFn: async () => {
      const parsed = taskSchema.parse(form);
      const { error } = await supabase.from("tasks").insert({
        project_id: parsed.project_id,
        title: parsed.title,
        description: parsed.description || null,
        priority: parsed.priority,
        due_date: parsed.due_date || null,
        assigned_to: parsed.assigned_to || null,
        created_by: user!.id,
      });
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Task created");
      qc.invalidateQueries({ queryKey: ["tasks"] });
      setOpen(false);
      setForm({ project_id: "", title: "", description: "", priority: "medium", due_date: "", assigned_to: "" });
    },
    onError: (e: unknown) => {
      const msg = e instanceof z.ZodError ? e.issues[0].message : (e as Error).message;
      toast.error(msg);
    },
  });

  const projectMap = new Map((projects.data ?? []).map((p) => [p.id, p]));
  const profileMap = new Map((profiles.data ?? []).map((p) => [p.id, p]));

  const filtered = (tasks.data ?? []).filter((t) => {
    if (scope === "mine" && t.assigned_to !== user?.id) return false;
    if (status !== "all" && t.status !== status) return false;
    if (search && !t.title.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-bold">Tasks</h1>
          <p className="text-sm text-muted-foreground">{filtered.length} shown</p>
        </div>
        {role === "admin" && (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button><Plus className="mr-1 h-4 w-4" />New task</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>Create task</DialogTitle></DialogHeader>
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label>Project</Label>
                  <Select value={form.project_id} onValueChange={(v) => setForm({ ...form, project_id: v })}>
                    <SelectTrigger><SelectValue placeholder="Select a project" /></SelectTrigger>
                    <SelectContent>
                      {(projects.data ?? []).length === 0 && <SelectItem value="none" disabled>No projects yet</SelectItem>}
                      {(projects.data ?? []).map((p) => <SelectItem key={p.id} value={p.id}>{p.title}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2"><Label>Title</Label><Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></div>
                <div className="space-y-2"><Label>Description</Label><Textarea rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <Label>Priority</Label>
                    <Select value={form.priority} onValueChange={(v) => setForm({ ...form, priority: v as typeof form.priority })}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="low">Low</SelectItem>
                        <SelectItem value="medium">Medium</SelectItem>
                        <SelectItem value="high">High</SelectItem>
                        <SelectItem value="urgent">Urgent</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2"><Label>Due date</Label><Input type="date" value={form.due_date} onChange={(e) => setForm({ ...form, due_date: e.target.value })} /></div>
                </div>
                <div className="space-y-2">
                  <Label>Assignee</Label>
                  <Select value={form.assigned_to} onValueChange={(v) => setForm({ ...form, assigned_to: v })}>
                    <SelectTrigger><SelectValue placeholder="Unassigned" /></SelectTrigger>
                    <SelectContent>
                      {(profiles.data ?? []).map((p) => <SelectItem key={p.id} value={p.id}>{p.name || p.email}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <DialogFooter><Button onClick={() => create.mutate()} disabled={create.isPending}>Create</Button></DialogFooter>
            </DialogContent>
          </Dialog>
        )}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-64">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input placeholder="Search tasks..." className="pl-9" value={search} onChange={(e) => setSearch(e.target.value)} />
        </div>
        <Select value={scope} onValueChange={(v) => setScope(v as typeof scope)}>
          <SelectTrigger className="w-36"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="mine">My tasks</SelectItem>
            <SelectItem value="all">All tasks</SelectItem>
          </SelectContent>
        </Select>
        <Select value={status} onValueChange={setStatus}>
          <SelectTrigger className="w-40"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            <SelectItem value="todo">To do</SelectItem>
            <SelectItem value="in_progress">In progress</SelectItem>
            <SelectItem value="review">Review</SelectItem>
            <SelectItem value="done">Done</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {tasks.isLoading ? (
        <div className="space-y-2">{[...Array(5)].map((_, i) => <Skeleton key={i} className="h-16" />)}</div>
      ) : filtered.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-16 text-center">
            <CheckSquare className="h-12 w-12 text-muted-foreground/40" />
            <p className="mt-3 text-sm text-muted-foreground">No tasks match your filters.</p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-2">
          {filtered.map((t) => {
            const project = projectMap.get(t.project_id);
            const assignee = t.assigned_to ? profileMap.get(t.assigned_to) : null;
            const canEdit = role === "admin" || t.assigned_to === user?.id;
            return (
              <Card key={t.id}>
                <CardContent className="flex flex-wrap items-center gap-4 p-4">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className="truncate font-medium">{t.title}</p>
                      <span className={`text-[10px] font-bold uppercase ${PRIORITY_COLOR[t.priority]}`}>{t.priority}</span>
                    </div>
                    <div className="mt-1 flex items-center gap-3 text-xs text-muted-foreground">
                      {project && (
                        <Link to="/projects/$projectId" params={{ projectId: project.id }} className="hover:text-primary-glow">
                          {project.title}
                        </Link>
                      )}
                      {t.due_date && <span className="flex items-center gap-1"><Calendar className="h-3 w-3" />{new Date(t.due_date).toLocaleDateString()}</span>}
                      {assignee && <Badge variant="outline" className="text-[10px]">{assignee.name || assignee.email}</Badge>}
                    </div>
                  </div>
                  <Select value={t.status} onValueChange={(v) => update.mutate({ id: t.id, status: v as "todo" | "in_progress" | "review" | "done" })} disabled={!canEdit}>
                    <SelectTrigger className="w-36"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="todo">To do</SelectItem>
                      <SelectItem value="in_progress">In progress</SelectItem>
                      <SelectItem value="review">Review</SelectItem>
                      <SelectItem value="done">Done</SelectItem>
                    </SelectContent>
                  </Select>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
