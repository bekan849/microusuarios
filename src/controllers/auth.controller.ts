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

    return res.json({
      ok: true,
      data,
    });
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
        ...req.user,
        roles: accesosActualizados.roles,
        permisos: accesosActualizados.permisos,
      },
    });
  } catch (err: any) {
    return res.status(400).json({
      ok: false,
      message: err?.message || "Error obteniendo sesión",
    });
  }
}