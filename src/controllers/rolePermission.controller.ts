import type { Request, Response } from "express";
import {
  listarPermisosDeRol,
  listarRolesDePermiso,
  asignarPermisoARol,
  quitarPermisoDeRol,
} from "../services/rolePermission.service";

type ReqRolId = Request<{ idrol: string }>;
type ReqPermisoId = Request<{ idpermiso: string }>;

export async function getPermisosDeRol(req: ReqRolId, res: Response) {
  try {
    const data = await listarPermisosDeRol(req.params.idrol);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function getRolesDePermiso(req: ReqPermisoId, res: Response) {
  try {
    const data = await listarRolesDePermiso(req.params.idpermiso);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function postRolPermiso(req: Request, res: Response) {
  try {
    const data = await asignarPermisoARol(req.body);
    return res.status(201).json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function deleteRolPermiso(req: Request, res: Response) {
  try {
    const data = await quitarPermisoDeRol(req.body);
    return res.json({
      ok: true,
      data,
      message: "Permiso quitado del rol correctamente",
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}