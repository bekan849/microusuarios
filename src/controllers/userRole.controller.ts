import type { Request, Response } from "express";
import {
  listarRolesDeUsuario,
  listarUsuariosDeRol,
  asignarRolAUsuario,
  actualizarEstadoUsuarioRol,
  quitarRolDeUsuario,
} from "../services/userRole.service";

type ReqUsuarioId = Request<{ idusuario: string }>;
type ReqRolId = Request<{ idrol: string }>;
type ReqUsuarioRolId = Request<{ idusuariorol: string }>;

export async function getRolesDeUsuario(req: ReqUsuarioId, res: Response) {
  try {
    const data = await listarRolesDeUsuario(req.params.idusuario);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function getUsuariosDeRol(req: ReqRolId, res: Response) {
  try {
    const data = await listarUsuariosDeRol(req.params.idrol);
    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function postUsuarioRol(req: Request, res: Response) {
  try {
    const data = await asignarRolAUsuario(req.body);
    return res.status(201).json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function patchUsuarioRolEstado(
  req: ReqUsuarioRolId,
  res: Response
) {
  try {
    const { estado } = req.body as { estado: boolean };

    if (typeof estado !== "boolean") {
      return res
        .status(400)
        .json({ ok: false, message: "estado debe ser boolean" });
    }

    const data = await actualizarEstadoUsuarioRol(
      req.params.idusuariorol,
      estado
    );

    return res.json({ ok: true, data });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}

export async function deleteUsuarioRol(req: Request, res: Response) {
  try {
    const data = await quitarRolDeUsuario(req.body);
    return res.json({
      ok: true,
      data,
      message: "Rol quitado del usuario correctamente",
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Error inesperado";
    return res.status(400).json({ ok: false, message });
  }
}