import jwt from "jsonwebtoken";
import { supabaseAdmin, supabaseAuth } from "../lib/supabase";
import { env } from "../config/env";
import { obtenerAccesosDeUsuario } from "./user.service";

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
  const email = normalizeEmail(payload.email);
  const password = String(payload.password ?? "");

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

  const accesos = await obtenerAccesosDeUsuario(usuario.idusuario);

  const roles = accesos.roles.map((r) => r.nombre);
  const permisos = accesos.permisos.map((p) => p.codigo);

  const tokenPayload: JwtPayload = {
    idusuario: usuario.idusuario,
    uidauth: usuario.uidauth ?? uidAuth,
    email: usuario.email,
    roles,
    permisos,
  };

  const token = jwt.sign(tokenPayload, env.JWT_SECRET, {
    expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions["expiresIn"],
  });

  await supabaseAdmin
    .from("usuarios")
    .update({ ultimo_acceso: new Date().toISOString() })
    .eq("idusuario", usuario.idusuario);

  return {
    token,
    usuario: {
      idusuario: usuario.idusuario,
      uidauth: usuario.uidauth ?? uidAuth,
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