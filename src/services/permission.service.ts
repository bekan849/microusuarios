import { supabaseAdmin } from "../lib/supabase";

export type PermisoCreate = {
  codigo: string;
  nombre: string;
  modulo: string;
  descripcion?: string | null;
  estado?: boolean;
};

export type PermisoUpdate = Partial<PermisoCreate>;

export type PermisoListQuery = {
  q?: string;
  modulo?: string;
  estado?: "true" | "false";
  page?: number;
  limit?: number;
  orderBy?: "creado_en" | "codigo" | "nombre" | "modulo";
  order?: "asc" | "desc";
};

function normalizeCode(value: string) {
  return String(value ?? "").trim().toLowerCase();
}

function normalizeName(value: string) {
  return String(value ?? "").trim();
}

function normalizeModule(value: string) {
  return String(value ?? "").trim().toLowerCase();
}

function normalizeText(value?: string | null) {
  if (value === undefined || value === null) return null;
  const text = String(value).trim();
  return text ? text : null;
}

function parseUniqueMessage(errorMessage: string) {
  if (errorMessage.toLowerCase().includes("duplicate")) {
    return "Ya existe un permiso con ese código.";
  }
  return errorMessage;
}

export async function listarPermisos(query: PermisoListQuery) {
  const page = Math.max(1, Number(query.page ?? 1));
  const limitRaw = Number(query.limit ?? 20);
  const limit = Math.min(Math.max(limitRaw, 1), 200);
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  const orderBy = query.orderBy ?? "creado_en";
  const ascending = (query.order ?? "desc").toLowerCase() === "asc";

  let q = supabaseAdmin
    .from("permisos")
    .select(
      `
      idpermiso,
      codigo,
      nombre,
      modulo,
      descripcion,
      estado,
      creado_en
      `,
      { count: "exact" }
    )
    .order(orderBy, { ascending })
    .range(from, to);

  if (query.modulo && query.modulo.trim()) {
    q = q.eq("modulo", normalizeModule(query.modulo));
  }

  if (query.estado === "true") q = q.eq("estado", true);
  if (query.estado === "false") q = q.eq("estado", false);

  if (query.q && query.q.trim()) {
    const term = query.q.trim();
    q = q.or(
      `codigo.ilike.%${term}%,nombre.ilike.%${term}%,modulo.ilike.%${term}%,descripcion.ilike.%${term}%`
    );
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

export async function obtenerPermisoPorId(idpermiso: string) {
  if (!idpermiso) throw new Error("Falta idpermiso");

  const { data, error } = await supabaseAdmin
    .from("permisos")
    .select(
      `
      idpermiso,
      codigo,
      nombre,
      modulo,
      descripcion,
      estado,
      creado_en
      `
    )
    .eq("idpermiso", idpermiso)
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function crearPermiso(payload: PermisoCreate) {
  const codigo = normalizeCode(payload.codigo);
  const nombre = normalizeName(payload.nombre);
  const modulo = normalizeModule(payload.modulo);

  if (!codigo) throw new Error("codigo es obligatorio");
  if (!nombre) throw new Error("nombre es obligatorio");
  if (!modulo) throw new Error("modulo es obligatorio");

  const insertRow = {
    codigo,
    nombre,
    modulo,
    descripcion: normalizeText(payload.descripcion),
    estado: payload.estado ?? true,
  };

  const { data, error } = await supabaseAdmin
    .from("permisos")
    .insert([insertRow])
    .select(
      `
      idpermiso,
      codigo,
      nombre,
      modulo,
      descripcion,
      estado,
      creado_en
      `
    )
    .single();

  if (error) throw new Error(parseUniqueMessage(error.message));
  return data;
}

export async function actualizarPermiso(
  idpermiso: string,
  payload: PermisoUpdate
) {
  if (!idpermiso) throw new Error("Falta idpermiso");

  const update: Record<string, any> = {};

  if (payload.codigo !== undefined) {
    const codigo = normalizeCode(payload.codigo);
    if (!codigo) throw new Error("codigo no puede quedar vacío");
    update.codigo = codigo;
  }

  if (payload.nombre !== undefined) {
    const nombre = normalizeName(payload.nombre);
    if (!nombre) throw new Error("nombre no puede quedar vacío");
    update.nombre = nombre;
  }

  if (payload.modulo !== undefined) {
    const modulo = normalizeModule(payload.modulo);
    if (!modulo) throw new Error("modulo no puede quedar vacío");
    update.modulo = modulo;
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
    .from("permisos")
    .update(update)
    .eq("idpermiso", idpermiso)
    .select(
      `
      idpermiso,
      codigo,
      nombre,
      modulo,
      descripcion,
      estado,
      creado_en
      `
    )
    .single();

  if (error) throw new Error(parseUniqueMessage(error.message));
  return data;
}

export async function setEstadoPermiso(idpermiso: string, estado: boolean) {
  if (!idpermiso) throw new Error("Falta idpermiso");

  const { data, error } = await supabaseAdmin
    .from("permisos")
    .update({ estado })
    .eq("idpermiso", idpermiso)
    .select(
      `
      idpermiso,
      codigo,
      nombre,
      modulo,
      descripcion,
      estado,
      creado_en
      `
    )
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function eliminarPermiso(idpermiso: string) {
  if (!idpermiso) throw new Error("Falta idpermiso");

  const { data: asignaciones, error: asignacionesError } = await supabaseAdmin
    .from("rol_permiso")
    .select("idrolpermiso")
    .eq("idpermiso", idpermiso)
    .limit(1);

  if (asignacionesError) throw new Error(asignacionesError.message);

  if ((asignaciones ?? []).length > 0) {
    throw new Error(
      "No se puede eliminar el permiso porque está asignado a uno o más roles"
    );
  }

  const { data, error } = await supabaseAdmin
    .from("permisos")
    .delete()
    .eq("idpermiso", idpermiso)
    .select(
      `
      idpermiso,
      codigo,
      nombre,
      modulo,
      descripcion,
      estado,
      creado_en
      `
    )
    .single();

  if (error) throw new Error(error.message);
  return data;
}