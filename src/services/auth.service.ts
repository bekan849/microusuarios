import jwt from "jsonwebtoken";
import { supabaseAdmin, supabaseAuth } from "../lib/supabase";
import { env } from "../config/env";
import { obtenerAccesosCompatibles, type AccesosUsuario } from "./user.service";
import { faltaFuncionRpc } from "../utils/rpc";

export type LoginPayload = {
  email: string;
  password: string;
};

type JwtPayload = {
  idusuario: string;
  uidauth?: string | null;
  email: string;
  roles: string[];
  permisos: string[];
};

function normalizeEmail(email: string) {
  return String(email ?? "").trim().toLowerCase();
}

export async function loginUsuario(payload: LoginPayload) {
  const email = normalizeEmail(payload?.email);
  const password = String(payload?.password ?? "");

  if (!email) throw new Error("email es obligatorio");
  if (!password) throw new Error("password es obligatorio");

  const { data: authData, error: authError } =
    await supabaseAuth.auth.signInWithPassword({
      email,
      password,
    });

  if (authError || !authData.user) {
    throw new Error("Credenciales inválidas");
  }

  const uidAuth = authData.user.id;

  const { data: sesion, error: sesionError } = await supabaseAdmin.rpc(
    "iniciar_sesion_usuario", { p_uidauth: uidAuth, p_email: email }
  );
  if (!sesionError) {
    if (!sesion?.usuario || !Array.isArray(sesion.roles) || !Array.isArray(sesion.permisos)) {
      throw new Error("Respuesta de sesión inválida");
    }
    return crearRespuestaLogin(sesion as AccesosUsuario);
  }
  if (!faltaFuncionRpc(sesionError)) throw new Error(sesionError.message);

  let usuario: any = null;

  const { data: byUid, error: byUidError } = await supabaseAdmin
    .from("usuarios")
    .select("*")
    .eq("uidauth", uidAuth)
    .single();

  if (!byUidError && byUid) {
    usuario = byUid;
  } else {
    const { data: byEmail, error: byEmailError } = await supabaseAdmin
      .from("usuarios")
      .select("*")
      .eq("email", email)
      .single();

    if (byEmailError || !byEmail) {
      throw new Error(
        "El usuario autenticado no existe en la tabla usuarios"
      );
    }

    usuario = byEmail;

    if (usuario.uidauth && usuario.uidauth !== uidAuth) {
      throw new Error("La cuenta de autenticación no coincide con el usuario");
    }

    if (!usuario.uidauth) {
      const { data: updatedUser, error: updateUidError } = await supabaseAdmin
        .from("usuarios")
        .update({ uidauth: uidAuth })
        .eq("idusuario", usuario.idusuario)
        .select("*")
        .single();

      if (updateUidError || !updatedUser) {
        throw new Error("No se pudo sincronizar el UID del usuario");
      }

      usuario = updatedUser;
    }
  }

  if (usuario.estado !== "ACTIVO") {
    throw new Error("El usuario no está activo");
  }

  const accesos = await obtenerAccesosCompatibles(usuario.idusuario, usuario);
  const ultimoAcceso = new Date().toISOString();
  const { error: accesoError } = await supabaseAdmin.from("usuarios")
    .update({ ultimo_acceso: ultimoAcceso }).eq("idusuario", usuario.idusuario);
  if (accesoError) throw new Error(accesoError.message);
  accesos.usuario.ultimo_acceso = ultimoAcceso;
  return crearRespuestaLogin(accesos);
}

function crearRespuestaLogin(accesos: AccesosUsuario) {
  const usuario = accesos.usuario;

  const roles = accesos.roles.map((r) => r.nombre);
  const permisos = accesos.permisos.map((p) => p.codigo);

  const tokenPayload: JwtPayload = {
    idusuario: usuario.idusuario,
    uidauth: usuario.uidauth,
    email: usuario.email,
    roles,
    permisos,
  };

  const token = jwt.sign(tokenPayload, env.JWT_SECRET, {
    expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions["expiresIn"],
  });

  return {
    token,
    usuario: {
      idusuario: usuario.idusuario,
      uidauth: usuario.uidauth,
      nombre: usuario.nombre,
      apellido: usuario.apellido,
      email: usuario.email,
      telefono: usuario.telefono,
      direccion: usuario.direccion,
      estado: usuario.estado,
      ultimo_acceso: usuario.ultimo_acceso,
      creado_en: usuario.creado_en,
      actualizado_en: usuario.actualizado_en,
    },
    roles: accesos.roles,
    permisos: accesos.permisos,
  };
}

export function verificarToken(token: string) {
  return jwt.verify(token, env.JWT_SECRET);
}
