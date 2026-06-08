import { supabaseAdmin } from "../lib/supabase";

export type RolCreate = {
  nombre: string;
  descripcion?: string | null;
  estado?: boolean;
};

export type RolUpdate = Partial<RolCreate>;

export type RolListQuery = {
  q?: string;
  estado?: "true" | "false";
  page?: number;
  limit?: number;
  orderBy?: "creado_en" | "nombre";
  order?: "asc" | "desc";
};

function normalizeNombre(nombre: string) {
  return String(nombre ?? "").trim().toUpperCase();
}

function normalizeText(value?: string | null) {
  if (value === undefined || value === null) return null;
  const text = String(value).trim();
  return text ? text : null;
}

function parseUniqueMessage(errorMessage: string) {
  if (errorMessage.toLowerCase().includes("duplicate")) {
    return "Ya existe un rol con ese nombre.";
  }
  return errorMessage;
}

export async function listarRoles(query: RolListQuery) {
  const page = Math.max(1, Number(query.page ?? 1));
  const limitRaw = Number(query.limit ?? 20);
  const limit = Math.min(Math.max(limitRaw, 1), 200);
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  const orderBy = query.orderBy ?? "creado_en";
  const ascending = (query.order ?? "desc").toLowerCase() === "asc";

  let q = supabaseAdmin
    .from("roles")
    .select(
      `
      idrol,
      nombre,
      descripcion,
      estado,
      creado_en,
      actualizado_en
      `,
      { count: "exact" }
    )
    .order(orderBy, { ascending })
    .range(from, to);

  if (query.estado === "true") q = q.eq("estado", true);
  if (query.estado === "false") q = q.eq("estado", false);

  if (query.q && query.q.trim()) {
    const term = query.q.trim();
    q = q.or(`nombre.ilike.%${term}%,descripcion.ilike.%${term}%`);
  }

  const { data, error, count } = await q;

  if (error) throw new Error(error.message);

  return {
    page,
    limit,
    total: count ?? 0,
    data: data ?? [],
  };
}

export async function obtenerRolPorId(idrol: string) {
  if (!idrol) throw new Error("Falta idrol");

  const { data, error } = await supabaseAdmin
    .from("roles")
    .select(
      `
      idrol,
      nombre,
      descripcion,
      estado,
      creado_en,
      actualizado_en
      `
    )
    .eq("idrol", idrol)
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function crearRol(payload: RolCreate) {
  const nombre = normalizeNombre(payload.nombre);

  if (!nombre) throw new Error("nombre es obligatorio");

  const insertRow = {
    nombre,
    descripcion: normalizeText(payload.descripcion),
    estado: payload.estado ?? true,
  };

  const { data, error } = await supabaseAdmin
    .from("roles")
    .insert([insertRow])
    .select(
      `
      idrol,
      nombre,
      descripcion,
      estado,
      creado_en,
      actualizado_en
      `
    )
    .single();

  if (error) throw new Error(parseUniqueMessage(error.message));
  return data;
}

export async function actualizarRol(idrol: string, payload: RolUpdate) {
  if (!idrol) throw new Error("Falta idrol");

  const update: Record<string, any> = {};

  if (payload.nombre !== undefined) {
    const nombre = normalizeNombre(payload.nombre);
    if (!nombre) throw new Error("nombre no puede quedar vacío");
    update.nombre = nombre;
  }

  if (payload.descripcion !== undefined) {
    update.descripcion = normalizeText(payload.descripcion);
  }

  if (payload.estado !== undefined) {
    update.estado = Boolean(payload.estado);
  }

  if (Object.keys(update).length === 0) {
    throw new Error("No hay campos para actualizar");
  }

  const { data, error } = await supabaseAdmin
    .from("roles")
    .update(update)
    .eq("idrol", idrol)
    .select(
      `
      idrol,
      nombre,
      descripcion,
      estado,
      creado_en,
      actualizado_en
      `
    )
    .single();

  if (error) throw new Error(parseUniqueMessage(error.message));
  return data;
}

export async function setEstadoRol(idrol: string, estado: boolean) {
  if (!idrol) throw new Error("Falta idrol");

  const { data, error } = await supabaseAdmin
    .from("roles")
    .update({ estado })
    .eq("idrol", idrol)
    .select(
      `
      idrol,
      nombre,
      descripcion,
      estado,
      creado_en,
      actualizado_en
      `
    )
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function eliminarRol(idrol: string) {
  if (!idrol) throw new Error("Falta idrol");

  const { data: asignaciones, error: asignacionesError } = await supabaseAdmin
    .from("usuario_rol")
    .select("idusuariorol")
    .eq("idrol", idrol)
    .limit(1);

  if (asignacionesError) throw new Error(asignacionesError.message);

  if ((asignaciones ?? []).length > 0) {
    throw new Error("No se puede eliminar el rol porque está asignado a uno o más usuarios");
  }

  const { data: permisos, error: permisosError } = await supabaseAdmin
    .from("rol_permiso")
    .select("idrolpermiso")
    .eq("idrol", idrol);

  if (permisosError) throw new Error(permisosError.message);

  if ((permisos ?? []).length > 0) {
    const { error: deletePermisosError } = await supabaseAdmin
      .from("rol_permiso")
      .delete()
      .eq("idrol", idrol);

    if (deletePermisosError) throw new Error(deletePermisosError.message);
  }

  const { data, error } = await supabaseAdmin
    .from("roles")
    .delete()
    .eq("idrol", idrol)
    .select(
      `
      idrol,
      nombre,
      descripcion,
      estado,
      creado_en,
      actualizado_en
      `
    )
    .single();

  if (error) throw new Error(error.message);
  return data;
}