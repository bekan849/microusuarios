import type { Request, Response } from "express";
import {
  listarRoles,
  obtenerRolPorId,
  crearRol,
  actualizarRol,
  setEstadoRol,
  eliminarRol,
} from "../services/role.service";

type ReqWithId = Request<{ id: string }>;

export async function getRoles(req: Request, res: Response) {
  try {
    const data = await listarRoles(req.query as any);
    return res.json({ ok: true, ...data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function getRolById(req: ReqWithId, res: Response) {
  try {
    const data = await obtenerRolPorId(req.params.id);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(404).json({ ok: false, message });
  }
}

export async function postRol(req: Request, res: Response) {
  try {
    const data = await crearRol(req.body);
    return res.status(201).json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function putRol(req: ReqWithId, res: Response) {
  try {
    const data = await actualizarRol(req.params.id, req.body);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function patchRolEstado(req: ReqWithId, res: Response) {
  try {
    const { estado } = req.body;

    if (typeof estado !== "boolean") {
      return res
        .status(400)
        .json({ ok: false, message: "estado debe ser boolean" });
    }

    const data = await setEstadoRol(req.params.id, estado);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function deleteRol(req: ReqWithId, res: Response) {
  try {
    const data = await eliminarRol(req.params.id);
    return res.json({ ok: true, data, message: "Rol eliminado correctamente" });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}