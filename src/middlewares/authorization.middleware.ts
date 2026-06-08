import type { NextFunction, Request, Response, RequestHandler } from "express";
import { obtenerAccesosDeUsuario } from "../services/user.service";

type AuthenticatedRequest = Request & {
  user?: {
    idusuario: string;
    email?: string;
    roles?: string[];
    permisos?: string[];
  };
};

function unauthorized(res: Response, message = "No autenticado") {
  return res.status(401).json({
    ok: false,
    message,
  });
}

function forbidden(res: Response, message = "No autorizado") {
  return res.status(403).json({
    ok: false,
    message,
  });
}

export const requireAuth: RequestHandler = (req, res, next) => {
  const authReq = req as AuthenticatedRequest;

  if (!authReq.user?.idusuario) {
    return unauthorized(res, "Debes iniciar sesión");
  }

  return next();
};

export function requireRole(roleName: string): RequestHandler {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const authReq = req as AuthenticatedRequest;

      if (!authReq.user?.idusuario) {
        return unauthorized(res, "Debes iniciar sesión");
      }

      const accesos = await obtenerAccesosDeUsuario(authReq.user.idusuario);

      const hasRole = accesos.roles.some(
        (rol) =>
          String(rol.nombre).toUpperCase() === String(roleName).toUpperCase()
      );

      if (!hasRole) {
        return forbidden(res, `Requiere el rol: ${roleName}`);
      }

      return next();
    } catch (err: any) {
      return res.status(400).json({
        ok: false,
        message: err?.message || "Error validando rol",
      });
    }
  };
}

export function requirePermission(permissionCode: string): RequestHandler {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const authReq = req as AuthenticatedRequest;

      if (!authReq.user?.idusuario) {
        return unauthorized(res, "Debes iniciar sesión");
      }

      const accesos = await obtenerAccesosDeUsuario(authReq.user.idusuario);

      const hasPermission = accesos.permisos.some(
        (permiso) =>
          String(permiso.codigo).toLowerCase() ===
          String(permissionCode).toLowerCase()
      );

      if (!hasPermission) {
        return forbidden(res, `Requiere el permiso: ${permissionCode}`);
      }

      return next();
    } catch (err: any) {
      return res.status(400).json({
        ok: false,
        message: err?.message || "Error validando permiso",
      });
    }
  };
}

export function requireAnyPermission(permissionCodes: string[]): RequestHandler {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const authReq = req as AuthenticatedRequest;

      if (!authReq.user?.idusuario) {
        return unauthorized(res, "Debes iniciar sesión");
      }

      const accesos = await obtenerAccesosDeUsuario(authReq.user.idusuario);

      const normalized = permissionCodes.map((p) => String(p).toLowerCase());

      const hasPermission = accesos.permisos.some((permiso) =>
        normalized.includes(String(permiso.codigo).toLowerCase())
      );

      if (!hasPermission) {
        return forbidden(
          res,
          `Requiere uno de estos permisos: ${permissionCodes.join(", ")}`
        );
      }

      return next();
    } catch (err: any) {
      return res.status(400).json({
        ok: false,
        message: err?.message || "Error validando permisos",
      });
    }
  };
}