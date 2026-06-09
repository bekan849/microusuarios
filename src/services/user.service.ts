import { supabaseAdmin } from "../lib/supabase";

export type UsuarioCreate = {
  uidauth?: string;
  nombre: string;
  apellido: string;
  email: string;
  password: string;
  telefono?: string | null;
  direccion?: string | null;
};

export type UsuarioUpdate = Partial<UsuarioCreate>;

export type UsuarioListQuery = {
  q?: string;
  estado?: "ACTIVO" | "INACTIVO" | "BLOQUEADO";
  page?: number;
  limit?: number;
};

function normalizeText(value?: string | null) {
  if (!value) return null;
  const v = String(value).trim();
  return v || null;
}

function normalizeNombre(value: string) {
  return String(value).trim().toUpperCase();
}

function normalizeEmail(value: string) {
  return String(value).trim().toLowerCase();
}

function parseUniqueError(msg: string) {
  if (msg.toLowerCase().includes("duplicate")) {
    return "Ya existe un usuario con ese email";
  }
  return msg;
}

export async function listarUsuarios(query: UsuarioListQuery) {
  const page = Math.max(1, Number(query.page ?? 1));
  const limit = Math.min(Math.max(Number(query.limit ?? 20), 1), 100);
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let q = supabaseAdmin
    .from("usuarios")
    .select("*", { count: "exact" })
    .range(from, to)
    .order("creado_en", { ascending: false });

  if (query.estado) q = q.eq("estado", query.estado);

  if (query.q) {
    const term = query.q.trim();
    q = q.or(
      `nombre.ilike.%${term}%,apellido.ilike.%${term}%,email.ilike.%${term}%`
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

export async function obtenerUsuario(idusuario: string) {
  const { data, error } = await supabaseAdmin
    .from("usuarios")
    .select("*")
    .eq("idusuario", idusuario)
    .single();

  if (error) throw new Error("Usuario no encontrado");

  return data;
}

export async function crearUsuario(payload: UsuarioCreate) {
  const email = normalizeEmail(payload.email);
  const nombre = normalizeNombre(payload.nombre);
  const apellido = normalizeNombre(payload.apellido);
  const telefono = normalizeText(payload.telefono);
  const direccion = normalizeText(payload.direccion);
  const password = String(payload.password ?? "").trim();

  if (!nombre) throw new Error("nombre es obligatorio");
  if (!apellido) throw new Error("apellido es obligatorio");
  if (!email) throw new Error("email es obligatorio");
  if (!password || password.length < 6) {
    throw new Error("password debe tener al menos 6 caracteres");
  }

  const { data: authCreated, error: authError } =
    await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

  if (authError || !authCreated.user) {
    throw new Error(
      authError?.message || "No se pudo crear el usuario en Auth"
    );
  }

  const uid = authCreated.user.id;

  const { data, error } = await supabaseAdmin
    .from("usuarios")
    .insert([
      {
        uidauth: uid,
        nombre,
        apellido,
        email,
        telefono,
        direccion,
      },
    ])
    .select("*")
    .single();

  if (error) {
    await supabaseAdmin.auth.admin.deleteUser(uid);
    throw new Error(parseUniqueError(error.message));
  }

  return data;
}

export async function obtenerAccesosDeUsuario(idusuario: string) {
  if (!idusuario) throw new Error("Falta idusuario");

  const usuario = await obtenerUsuario(idusuario);

  if (usuario.estado !== "ACTIVO") {
    throw new Error("Usuario no activo");
  }

  const { data: rolesData, error: rolesError } = await supabaseAdmin
    .from("usuario_rol")
    .select(`
      idusuariorol,
      idusuario,
      idrol,
      estado,
      roles:roles (
        idrol,
        nombre,
        descripcion,
        estado
      )
    `)
    .eq("idusuario", idusuario)
    .eq("estado", true);

  if (rolesError) throw new Error(rolesError.message);

  const rolesMap = new Map<string, any>();

  for (const row of rolesData ?? []) {
    const rol = (row as any).roles;

    if (!rol || rol.estado !== true) continue;

    rolesMap.set(rol.idrol, {
      idrol: rol.idrol,
      nombre: String(rol.nombre ?? "").trim(),
      descripcion: rol.descripcion ?? null,
    });
  }

  const rolesActivos = Array.from(rolesMap.values());
  const roleIds = rolesActivos.map((rol) => rol.idrol).filter(Boolean);

  let permisosActivos: any[] = [];

  if (roleIds.length > 0) {
    const { data: permisosData, error: permisosError } = await supabaseAdmin
      .from("rol_permiso")
      .select(`
        idrol,
        idpermiso,
        permisos:permisos (
          idpermiso,
          codigo,
          nombre,
          modulo,
          descripcion,
          estado
        )
      `)
      .in("idrol", roleIds);

    if (permisosError) throw new Error(permisosError.message);

    const permisosMap = new Map<string, any>();

    for (const row of permisosData ?? []) {
      const permiso = (row as any).permisos;

      if (!permiso || permiso.estado !== true) continue;

      permisosMap.set(permiso.idpermiso, {
        idpermiso: permiso.idpermiso,
        codigo: String(permiso.codigo ?? "").trim().toLowerCase(),
        nombre: permiso.nombre,
        modulo: permiso.modulo,
        descripcion: permiso.descripcion ?? null,
      });
    }

    permisosActivos = Array.from(permisosMap.values());
  }

  return {
    usuario,
    roles: rolesActivos,
    permisos: permisosActivos,
  };
}

export async function actualizarUsuario(
  idusuario: string,
  payload: UsuarioUpdate
) {
  const actual = await obtenerUsuario(idusuario);

  const update: any = {};

  if (payload.nombre !== undefined) {
    update.nombre = normalizeNombre(payload.nombre);
  }

  if (payload.apellido !== undefined) {
    update.apellido = normalizeNombre(payload.apellido);
  }

  if (payload.telefono !== undefined) {
    update.telefono = normalizeText(payload.telefono);
  }

  if (payload.direccion !== undefined) {
    update.direccion = normalizeText(payload.direccion);
  }

  if (payload.email !== undefined) {
    const newEmail = normalizeEmail(payload.email);
    update.email = newEmail;

    if (newEmail !== actual.email) {
      if (!actual.uidauth) {
        throw new Error("El usuario no tiene uidauth para sincronizar email");
      }

      const { error: authError } =
        await supabaseAdmin.auth.admin.updateUserById(actual.uidauth, {
          email: newEmail,
        });

      if (authError) {
        throw new Error(
          `No se pudo actualizar el email en Auth: ${authError.message}`
        );
      }
    }
  }

  if (Object.keys(update).length === 0) {
    throw new Error("No hay datos para actualizar");
  }

  const { data, error } = await supabaseAdmin
    .from("usuarios")
    .update(update)
    .eq("idusuario", idusuario)
    .select("*")
    .single();

  if (error) throw new Error(parseUniqueError(error.message));

  return data;
}

export async function cambiarEstadoUsuario(
  idusuario: string,
  estado: "ACTIVO" | "INACTIVO" | "BLOQUEADO"
) {
  const { data, error } = await supabaseAdmin
    .from("usuarios")
    .update({ estado })
    .eq("idusuario", idusuario)
    .select("*")
    .single();

  if (error) throw new Error(error.message);

  return data;
}

export async function eliminarUsuario(idusuario: string) {
  const actual = await obtenerUsuario(idusuario);

  if (actual.uidauth) {
    const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(
      actual.uidauth
    );

    if (authError) {
      throw new Error(
        `No se pudo eliminar el usuario de Auth: ${authError.message}`
      );
    }
  }

  const { error } = await supabaseAdmin
    .from("usuarios")
    .delete()
    .eq("idusuario", idusuario);

  if (error) throw new Error(error.message);

  return { ok: true };
}

export async function cambiarPasswordUsuario(
  idusuario: string,
  password: string
) {
  const actual = await obtenerUsuario(idusuario);

  const newPassword = String(password ?? "").trim();

  if (!newPassword || newPassword.length < 6) {
    throw new Error("La nueva contraseña debe tener al menos 6 caracteres");
  }

  if (!actual.uidauth) {
    throw new Error("El usuario no tiene uidauth para cambiar contraseña");
  }

  const { error } = await supabaseAdmin.auth.admin.updateUserById(
    actual.uidauth,
    { password: newPassword }
  );

  if (error) {
    throw new Error(`No se pudo actualizar la contraseña: ${error.message}`);
  }

  return { ok: true };
}