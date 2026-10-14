import jwt from 'jsonwebtoken';
import { supabaseSystem, supabaseAuth } from '../lib/supabase';
import { env } from '../config/env';
import type { AccesosUsuario } from './user.service';
import { listarEmpresas, obtenerAccesosEmpresa, type Empresa } from './empresa.service';

export type LoginPayload = { email: string; password: string };
export async function loginUsuario(payload: LoginPayload) {
  const email = String(payload?.email ?? '').trim().toLowerCase();
  const password = String(payload?.password ?? '');
  if (!email || !password) throw new Error('Correo y contraseña son obligatorios');
  const { data, error } = await supabaseAuth.auth.signInWithPassword({ email, password });
  if (error || !data.user) throw new Error('Credenciales inválidas');
  const { data: sesion, error: sessionError } = await supabaseSystem.rpc('iniciar_sesion_multiempresa', {
    p_uidauth: data.user.id, p_email: email,
  });
  if (sessionError) throw new Error(sessionError.message);
  if (!sesion?.usuario || !Array.isArray(sesion.empresas) || !sesion.empresas.length)
    throw new Error('No tienes empresas habilitadas');
  if (sesion.empresas.length === 1) return seleccionarEmpresa(sesion.usuario.idusuario, sesion.empresas[0].idempresa);
  return crearRespuestaLogin({ usuario: sesion.usuario, roles: [], permisos: [] }, sesion.empresas);
}

export async function seleccionarEmpresa(idusuario: string, idempresa: string) {
  const accesos = await obtenerAccesosEmpresa(idusuario, idempresa);
  const empresas = await listarEmpresas(idusuario);
  return crearRespuestaLogin(accesos, empresas, accesos.empresa);
}

function crearRespuestaLogin(accesos: AccesosUsuario, empresas: Empresa[], empresa?: Empresa) {
  const u = accesos.usuario;
  const tipo = empresa ? 'empresa' : 'seleccion_empresa';
  const token = jwt.sign({
    version: 2, tipo, idempresa: empresa?.idempresa, idusuario: u.idusuario,
    nombre: u.nombre, apellido: u.apellido, email: u.email,
    // Los permisos vigentes se consultan en servidor en cada petición.
  }, env.JWT_SECRET, { algorithm: 'HS256', expiresIn: tipo === 'seleccion_empresa' ? '10m' : env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'] });
  return { token, usuario: {
    idusuario:u.idusuario,uidauth:u.uidauth,nombre:u.nombre,apellido:u.apellido,email:u.email,
    telefono:u.telefono,direccion:u.direccion,estado:u.estado,ultimo_acceso:u.ultimo_acceso,
    creado_en:u.creado_en,actualizado_en:u.actualizado_en,
  }, roles:accesos.roles,permisos:accesos.permisos,empresas,empresa:empresa ?? null };
}

export function verificarToken(token: string) {
  return jwt.verify(token, env.JWT_SECRET, { algorithms: ['HS256'] });
}
