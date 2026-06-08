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
  postPermiso
);

permissionRouter.put(
  "/:id",
  decodeToken,
  requireAuth,
  requirePermission("permisos.editar"),
  putPermiso
);

permissionRouter.patch(
  "/:id/estado",
  decodeToken,
  requireAuth,
  requirePermission("permisos.editar"),
  patchPermisoEstado
);

permissionRouter.delete(
  "/:id",
  decodeToken,
  requireAuth,
  requireRole("ADMINISTRADOR"),
  deletePermiso
);