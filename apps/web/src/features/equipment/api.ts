import { supabase } from "@/services/supabaseClient";
import type { Equipment, EquipmentStatusEvent, EquipmentStatus, EquipmentType } from "@/types/database";

export async function listEquipment(): Promise<Equipment[]> {
  const { data, error } = await supabase
    .from("equipment")
    .select("*")
    .order("equipment_code", { ascending: true });
  if (error) throw error;
  return (data ?? []) as Equipment[];
}

export async function getEquipment(id: string): Promise<Equipment> {
  const { data, error } = await supabase.from("equipment").select("*").eq("id", id).single();
  if (error) throw error;
  return data as Equipment;
}

export async function getEquipmentStatusHistory(equipmentId: string): Promise<EquipmentStatusEvent[]> {
  const { data, error } = await supabase
    .from("equipment_status_events")
    .select("*")
    .eq("equipment_id", equipmentId)
    .order("changed_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as EquipmentStatusEvent[];
}

export interface CreateEquipmentInput {
  organization_id: string;
  department_id?: string | null;
  equipment_code: string;
  equipment_type: EquipmentType;
  manufacturer?: string;
  model_name?: string;
  serial_number?: string;
  location?: string;
}

export async function createEquipment(input: CreateEquipmentInput): Promise<Equipment> {
  const { data, error } = await supabase.from("equipment").insert(input).select().single();
  if (error) throw error;
  return data as Equipment;
}

export async function updateEquipmentStatus(
  id: string,
  operating_status: EquipmentStatus,
): Promise<Equipment> {
  const { data, error } = await supabase
    .from("equipment")
    .update({ operating_status })
    .eq("id", id)
    .select()
    .single();
  if (error) throw error;
  return data as Equipment;
}
