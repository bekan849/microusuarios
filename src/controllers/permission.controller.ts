import type { Request, Response } from "express";
import {
  listarPermisos,
  obtenerPermisoPorId,
  crearPermiso,
  actualizarPermiso,
  setEstadoPermiso,
  eliminarPermiso,
} from "../services/permission.service";

type ReqWithId = Request<{ id: string }>;

export async function getPermisos(req: Request, res: Response) {
  try {
    const data = await listarPermisos(req.query as any);
    return res.json({ ok: true, ...data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function getPermisoById(req: ReqWithId, res: Response) {
  try {
    const data = await obtenerPermisoPorId(req.params.id);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(404).json({ ok: false, message });
  }
}

export async function postPermiso(req: Request, res: Response) {
  try {
    const data = await crearPermiso(req.body);
    return res.status(201).json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function putPermiso(req: ReqWithId, res: Response) {
  try {
    const data = await actualizarPermiso(req.params.id, req.body);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function patchPermisoEstado(req: ReqWithId, res: Response) {
  try {
    const { estado } = req.body;

    if (typeof estado !== "boolean") {
      return res
        .status(400)
        .json({ ok: false, message: "estado debe ser boolean" });
    }

    const data = await setEstadoPermiso(req.params.id, estado);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function deletePermiso(req: ReqWithId, res: Response) {
  try {
    const data = await eliminarPermiso(req.params.id);
    return res.json({
      ok: true,
      data,
      message: "Permiso eliminado correctamente",
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}