import { auditMiddleware } from "../middlewares/audit.middleware";
import { Router } from "express";
import {
  getPermisosDeRol,
  getRolesDePermiso,
  postRolPermiso,
  deleteRolPermiso,
} from "../controllers/rolePermission.controller";

import { decodeToken } from "../middlewares/auth.middleware";
import {
  requireAuth,
  requirePermission,
} from "../middlewares/authorization.middleware";

export const rolePermissionRouter = Router();

rolePermissionRouter.get(
  "/rol/:idrol",
  decodeToken,
  requireAuth,
  requirePermission("roles.ver"),
  getPermisosDeRol
);

rolePermissionRouter.get(
  "/permiso/:idpermiso",
  decodeToken,
  requireAuth,
  requirePermission("permisos.ver"),
  getRolesDePermiso
);

rolePermissionRouter.post(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("roles.editar"),
  auditMiddleware("usuarios"),
  postRolPermiso
);

rolePermissionRouter.delete(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("roles.editar"),
  auditMiddleware("usuarios"),
  deleteRolPermiso
);