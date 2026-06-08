import { supabaseAdmin } from "../lib/supabase";

export type RolPermisoAssignPayload = {
  idrol: string;
  idpermiso: string;
};

export type RolPermisoRemovePayload = {
  idrol: string;
  idpermiso: string;
};

async function validarRol(idrol: string) {
  if (!idrol) throw new Error("idrol es obligatorio");

  const { data, error } = await supabaseAdmin
    .from("roles")
    .select("idrol, nombre, estado")
    .eq("idrol", idrol)
    .single();

  if (error || !data) {
    throw new Error("No se encontró el rol");
  }

  return data;
}

async function validarPermiso(idpermiso: string) {
  if (!idpermiso) throw new Error("idpermiso es obligatorio");

  const { data, error } = await supabaseAdmin
    .from("permisos")
    .select("idpermiso, codigo, nombre, estado")
    .eq("idpermiso", idpermiso)
    .single();

  if (error || !data) {
    throw new Error("No se encontró el permiso");
  }

  return data;
}

function parseUniqueMessage(errorMessage: string) {
  if (errorMessage.toLowerCase().includes("duplicate")) {
    return "Ese permiso ya está asignado al rol.";
  }
  return errorMessage;
}

export async function listarPermisosDeRol(idrol: string) {
  await validarRol(idrol);

  const { data, error } = await supabaseAdmin
    .from("rol_permiso")
    .select(`
      idrolpermiso,
      creado_en,
      permisos:permisos (
        idpermiso,
        codigo,
        nombre,
        modulo,
        descripcion,
        estado,
        creado_en
      )
    `)
    .eq("idrol", idrol)
    .order("creado_en", { ascending: true });

  if (error) throw new Error(error.message);

  return data ?? [];
}

export async function listarRolesDePermiso(idpermiso: string) {
  await validarPermiso(idpermiso);

  const { data, error } = await supabaseAdmin
    .from("rol_permiso")
    .select(`
      idrolpermiso,
      creado_en,
      roles:roles (
        idrol,
        nombre,
        descripcion,
        estado,
        creado_en,
        actualizado_en
      )
    `)
    .eq("idpermiso", idpermiso)
    .order("creado_en", { ascending: true });

  if (error) throw new Error(error.message);

  return data ?? [];
}

export async function asignarPermisoARol(payload: RolPermisoAssignPayload) {
  await validarRol(payload.idrol);
  await validarPermiso(payload.idpermiso);

  const { data, error } = await supabaseAdmin
    .from("rol_permiso")
    .insert([
      {
        idrol: payload.idrol,
        idpermiso: payload.idpermiso,
      },
    ])
    .select(`
      idrolpermiso,
      idrol,
      idpermiso,
      creado_en
    `)
    .single();

  if (error) throw new Error(parseUniqueMessage(error.message));
  return data;
}

export async function quitarPermisoDeRol(payload: RolPermisoRemovePayload) {
  await validarRol(payload.idrol);
  await validarPermiso(payload.idpermiso);

  const { data: existente, error: existenteError } = await supabaseAdmin
    .from("rol_permiso")
    .select("idrolpermiso, idrol, idpermiso, creado_en")
    .eq("idrol", payload.idrol)
    .eq("idpermiso", payload.idpermiso)
    .single();

  if (existenteError || !existente) {
    throw new Error("La relación rol-permiso no existe");
  }

  const { error } = await supabaseAdmin
    .from("rol_permiso")
    .delete()
    .eq("idrol", payload.idrol)
    .eq("idpermiso", payload.idpermiso);

  if (error) throw new Error(error.message);

  return existente;
}