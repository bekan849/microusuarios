import { auditMiddleware } from "../middlewares/audit.middleware";
import { Router } from "express";
import {
  getPermisos,
  getPermisoById,
  postPermiso,
  putPermiso,
  patchPermisoEstado,
  deletePermiso,
} from "../controllers/permission.controller";

import { decodeToken } from "../middlewares/auth.middleware";
import {
  requireAuth,
  requirePermission,
  requireRole,
} from "../middlewares/authorization.middleware";

export const permissionRouter = Router();

permissionRouter.get(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("permisos.ver"),
  getPermisos
);

permissionRouter.get(
  "/:id",
  decodeToken,
  requireAuth,
  requirePermission("permisos.ver"),
  getPermisoById
);

permissionRouter.post(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("permisos.crear"),
  auditMiddleware("usuarios"),
  postPermiso
);

permissionRouter.put(
  "/:id",
  decodeToken,
  requireAuth,
  requirePermission("permisos.editar"),
  auditMiddleware("usuarios"),
  putPermiso
);

permissionRouter.patch(
  "/:id/estado",
  decodeToken,
  requireAuth,
  requirePermission("permisos.editar"),
  auditMiddleware("usuarios"),
  patchPermisoEstado
);

permissionRouter.delete(
  "/:id",
  decodeToken,
  requireAuth,
  requireRole("ADMINISTRADOR"),
  auditMiddleware("usuarios"),
  deletePermiso
);