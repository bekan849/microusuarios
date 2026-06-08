import { Request, Response } from "express";
import {
  listarUsuarios,
  obtenerUsuario,
  crearUsuario,
  actualizarUsuario,
  cambiarEstadoUsuario,
  eliminarUsuario,
  obtenerAccesosDeUsuario,
  cambiarPasswordUsuario,
} from "../services/user.service";

type ReqWithId = Request<{ id: string }>;

type UsuarioEstado = "ACTIVO" | "INACTIVO" | "BLOQUEADO";

export async function getUsuarios(req: Request, res: Response) {
  try {
    const data = await listarUsuarios(req.query as any);
    return res.json({ ok: true, ...data });
  } catch (err: any) {
    return res.status(400).json({ ok: false, message: err.message });
  }
}

export async function getUsuario(req: ReqWithId, res: Response) {
  try {
    const data = await obtenerUsuario(req.params.id);
    return res.json({ ok: true, data });
  } catch (err: any) {
    return res.status(404).json({ ok: false, message: err.message });
  }
}

export async function postUsuario(req: Request, res: Response) {
  try {
    const data = await crearUsuario(req.body);
    return res.status(201).json({ ok: true, data });
  } catch (err: any) {
    return res.status(400).json({ ok: false, message: err.message });
  }
}

export async function putUsuario(req: ReqWithId, res: Response) {
  try {
    const data = await actualizarUsuario(req.params.id, req.body);
    return res.json({ ok: true, data });
  } catch (err: any) {
    return res.status(400).json({ ok: false, message: err.message });
  }
}

export async function patchUsuarioEstado(req: ReqWithId, res: Response) {
  try {
    const { estado } = req.body as { estado: UsuarioEstado };
    const data = await cambiarEstadoUsuario(req.params.id, estado);
    return res.json({ ok: true, data });
  } catch (err: any) {
    return res.status(400).json({ ok: false, message: err.message });
  }
}

export async function deleteUsuario(req: ReqWithId, res: Response) {
  try {
    await eliminarUsuario(req.params.id);
    return res.json({ ok: true, message: "Usuario eliminado" });
  } catch (err: any) {
    return res.status(400).json({ ok: false, message: err.message });
  }
}

export async function getAccesosUsuario(req: ReqWithId, res: Response) {
  try {
    const data = await obtenerAccesosDeUsuario(req.params.id);
    return res.json({ ok: true, data });
  } catch (err: any) {
    return res.status(400).json({ ok: false, message: err.message });
  }
}

export async function patchUsuarioPassword(req: ReqWithId, res: Response) {
  try {
    const { password } = req.body as { password: string };
    const data = await cambiarPasswordUsuario(req.params.id, password);
    return res.json({ ok: true, data });
  } catch (err: any) {
    return res.status(400).json({ ok: false, message: err.message });
  }
}