import { supabaseAdmin } from "../lib/supabase";

export type UsuarioRolAssignPayload = {
  idusuario: string;
  idrol: string;
  estado?: boolean;
};

export type UsuarioRolRemovePayload = {
  idusuario: string;
  idrol: string;
};

async function validarUsuario(idusuario: string) {
  if (!idusuario) throw new Error("idusuario es obligatorio");

  const { data, error } = await supabaseAdmin
    .from("usuarios")
    .select("idusuario, nombre, apellido, email, estado")
    .eq("idusuario", idusuario)
    .single();

  if (error || !data) {
    throw new Error("No se encontró el usuario");
  }

  return data;
}

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

function parseUniqueMessage(errorMessage: string) {
  if (errorMessage.toLowerCase().includes("duplicate")) {
    return "Ese rol ya está asignado al usuario.";
  }
  return errorMessage;
}

export async function listarRolesDeUsuario(idusuario: string) {
  await validarUsuario(idusuario);

  const { data, error } = await supabaseAdmin
    .from("usuario_rol")
    .select(`
      idusuariorol,
      idusuario,
      idrol,
      estado,
      asignado_en,
      roles:roles (
        idrol,
        nombre,
        descripcion,
        estado,
        creado_en,
        actualizado_en
      )
    `)
    .eq("idusuario", idusuario)
    .order("asignado_en", { ascending: true });

  if (error) throw new Error(error.message);

  return data ?? [];
}

export async function listarUsuariosDeRol(idrol: string) {
  await validarRol(idrol);

  const { data, error } = await supabaseAdmin
    .from("usuario_rol")
    .select(`
      idusuariorol,
      idusuario,
      idrol,
      estado,
      asignado_en,
      usuarios:usuarios (
        idusuario,
        uidauth,
        nombre,
        apellido,
        email,
        telefono,
        direccion,
        estado,
        ultimo_acceso,
        creado_en,
        actualizado_en
      )
    `)
    .eq("idrol", idrol)
    .order("asignado_en", { ascending: true });

  if (error) throw new Error(error.message);

  return data ?? [];
}

export async function asignarRolAUsuario(payload: UsuarioRolAssignPayload) {
  const usuario = await validarUsuario(payload.idusuario);
  const rol = await validarRol(payload.idrol);

  if (usuario.estado !== "ACTIVO") {
    throw new Error("Solo se puede asignar roles a usuarios activos");
  }

  if (!rol.estado) {
    throw new Error("Solo se pueden asignar roles activos");
  }

  const { data, error } = await supabaseAdmin
    .from("usuario_rol")
    .insert([
      {
        idusuario: payload.idusuario,
        idrol: payload.idrol,
        estado: payload.estado ?? true,
      },
    ])
    .select(`
      idusuariorol,
      idusuario,
      idrol,
      estado,
      asignado_en
    `)
    .single();

  if (error) throw new Error(parseUniqueMessage(error.message));
  return data;
}

export async function actualizarEstadoUsuarioRol(
  idusuariorol: string,
  estado: boolean
) {
  if (!idusuariorol) throw new Error("idusuariorol es obligatorio");

  const { data, error } = await supabaseAdmin
    .from("usuario_rol")
    .update({ estado })
    .eq("idusuariorol", idusuariorol)
    .select(`
      idusuariorol,
      idusuario,
      idrol,
      estado,
      asignado_en
    `)
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function quitarRolDeUsuario(payload: UsuarioRolRemovePayload) {
  await validarUsuario(payload.idusuario);
  await validarRol(payload.idrol);

  const { data: existente, error: existenteError } = await supabaseAdmin
    .from("usuario_rol")
    .select(`
      idusuariorol,
      idusuario,
      idrol,
      estado,
      asignado_en
    `)
    .eq("idusuario", payload.idusuario)
    .eq("idrol", payload.idrol)
    .single();

  if (existenteError || !existente) {
    throw new Error("La relación usuario-rol no existe");
  }

  const { error } = await supabaseAdmin
    .from("usuario_rol")
    .delete()
    .eq("idusuario", payload.idusuario)
    .eq("idrol", payload.idrol);

  if (error) throw new Error(error.message);

  return existente;
}