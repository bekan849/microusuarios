import { empresaContext } from '../lib/empresa-context';
import type { Request, Response } from "express";
import { loginUsuario } from "../services/auth.service";
import { obtenerAccesosDeUsuario } from "../services/user.service";

type ReqWithUser = Request & {
  user?: {
    idusuario: string;
    email?: string;
    roles?: string[];
    permisos?: string[];
  };
};

export async function postLogin(req: Request, res: Response) {
  try {
    const data = await loginUsuario(req.body);
    res.locals.auditActor = data.usuario;

    const reply = () => res.json({ ok: true, data });
    return data.empresa ? empresaContext.run({ idempresa:data.empresa.idempresa,
      idusuario:data.usuario.idusuario,permisos:data.permisos.map(p=>p.codigo) },reply) : reply();
  } catch (err: any) {
    return res.status(400).json({
      ok: false,
      message: err?.message || "Error en login",
    });
  }
}

export async function getAuthMe(req: ReqWithUser, res: Response) {
  try {
    if (!req.user?.idusuario) {
      return res.status(401).json({
        ok: false,
        message: "No autenticado",
      });
    }

    const accesosActualizados = await obtenerAccesosDeUsuario(
      req.user.idusuario
    );

    return res.json({
      ok: true,
      data: {
        usuario: accesosActualizados.usuario,
        roles: accesosActualizados.roles,
        permisos: accesosActualizados.permisos,
        empresa: accesosActualizados.empresa,
      },
    });
  } catch (err: any) {
    return res.status(400).json({
      ok: false,
      message: err?.message || "Error obteniendo sesión",
    });
  }
}
