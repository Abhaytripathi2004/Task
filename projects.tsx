import { supabase } from "@/integrations/supabase/client";

export const fetchProjects = async () => {
  const { data, error } = await supabase
    .from("projects")
    .select("*")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
};

export const fetchProject = async (id: string) => {
  const { data, error } = await supabase.from("projects").select("*").eq("id", id).maybeSingle();
  if (error) throw error;
  return data;
};

export const fetchTasks = async (projectId?: string) => {
  let q = supabase.from("tasks").select("*").order("position", { ascending: true });
  if (projectId) q = q.eq("project_id", projectId);
  const { data, error } = await q;
  if (error) throw error;
  return data ?? [];
};

export const fetchProfiles = async () => {
  const { data, error } = await supabase.from("profiles").select("*").order("name");
  if (error) throw error;
  return data ?? [];
};

export const fetchRoles = async () => {
  const { data, error } = await supabase.from("user_roles").select("*");
  if (error) throw error;
  return data ?? [];
};

export const fetchProjectMembers = async (projectId: string) => {
  const { data, error } = await supabase
    .from("project_members")
    .select("*")
    .eq("project_id", projectId);
  if (error) throw error;
  return data ?? [];
};
