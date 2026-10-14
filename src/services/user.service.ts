import { supabaseAdmin, supabaseSystem } from "../lib/supabase";
import { requireEmpresaContext } from '../lib/empresa-context';
import { obtenerAccesosEmpresa } from './empresa.service';

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

function usuarioDeEmpresa(usuario: any) {
  const { __empresa, ...datos } = usuario;
  const membresia = Array.isArray(__empresa) ? __empresa[0] : __empresa;
  return { ...datos, estado: datos.estado === 'ACTIVO' && membresia?.activa === false ? 'INACTIVO' : datos.estado };
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

  if (query.estado === 'ACTIVO') q = q.eq('estado','ACTIVO').eq('__empresa.activa',true);
  else if (query.estado === 'INACTIVO') q = q.eq('__empresa.activa',false);
  else if (query.estado === 'BLOQUEADO') q = q.eq('estado','BLOQUEADO');

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
    data: (data ?? []).map(usuarioDeEmpresa),
  };
}

export async function obtenerUsuario(idusuario: string) {
  const { data, error } = await supabaseAdmin
    .from("usuarios")
    .select("*")
    .eq("idusuario", idusuario)
    .single();

  if (error) throw new Error("Usuario no encontrado");

  return usuarioDeEmpresa(data);
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
    await supabaseSystem.auth.admin.createUser({
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

  const { data, error } = await supabaseSystem.rpc('registrar_usuario_empresa', {
    p_idempresa: requireEmpresaContext().idempresa, p_actor: requireEmpresaContext().idusuario,
    p_usuario: { uidauth: uid, nombre, apellido, email, telefono, direccion },
  });

  if (error) {
    await supabaseSystem.auth.admin.deleteUser(uid);
    throw new Error(parseUniqueError(error.message));
  }

  return data;
}

export async function obtenerAccesosDeUsuario(idusuario: string) {
  return obtenerAccesosEmpresa(idusuario,requireEmpresaContext().idempresa);
}

export type AccesosUsuario = {
  usuario: any;
  roles: Array<{ idrol: string; nombre: string; descripcion: string | null }>;
  permisos: Array<{
    idpermiso: string; codigo: string; nombre: string;
    modulo: string; descripcion: string | null;
  }>;
};

export async function actualizarUsuario(
  idusuario: string,
  payload: UsuarioUpdate
) {
  const actual = await obtenerUsuario(idusuario);
  await autorizarCambioIdentidad(idusuario);

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
        await supabaseSystem.auth.admin.updateUserById(actual.uidauth, {
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

  const { data, error } = await supabaseSystem
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
  if (!['ACTIVO','INACTIVO','BLOQUEADO'].includes(estado)) throw new Error('Estado inválido');
  await obtenerUsuario(idusuario);
  const { error } = await supabaseSystem.from('empresa_usuario').update({activa:estado === 'ACTIVO'})
    .eq('idempresa',requireEmpresaContext().idempresa).eq('idusuario',idusuario);
  if (error) throw new Error(error.message);
  return obtenerUsuario(idusuario);
}

export async function eliminarUsuario(idusuario: string) {
  await cambiarEstadoUsuario(idusuario,'INACTIVO');
  return {ok:true}; // Quitar acceso a esta tienda conserva identidad e historial.
}

async function autorizarCambioIdentidad(idusuario: string) {
  const context=requireEmpresaContext();
  if (idusuario===context.idusuario) return;
  const {count,error}=await supabaseSystem.from('empresa_usuario').select('idusuario',{count:'exact',head:true}).eq('idusuario',idusuario);
  if(error || count!==1) throw new Error('La cuenta pertenece a varias empresas; su titular debe modificar sus datos personales');
}

export async function cambiarPasswordUsuario(
  idusuario: string,
  password: string
) {
  const actual = await obtenerUsuario(idusuario);
  await autorizarCambioIdentidad(idusuario);

  const newPassword = String(password ?? "").trim();

  if (!newPassword || newPassword.length < 6) {
    throw new Error("La nueva contraseña debe tener al menos 6 caracteres");
  }

  if (!actual.uidauth) {
    throw new Error("El usuario no tiene uidauth para cambiar contraseña");
  }

  const { error } = await supabaseSystem.auth.admin.updateUserById(
    actual.uidauth,
    { password: newPassword }
  );

  if (error) {
    throw new Error(`No se pudo actualizar la contraseña: ${error.message}`);
  }

  return { ok: true };
}
