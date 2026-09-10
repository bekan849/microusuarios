import { auditMiddleware } from "../middlewares/audit.middleware";
import { Router } from "express";
import {
  getRoles,
  getRolById,
  postRol,
  putRol,
  patchRolEstado,
  deleteRol,
} from "../controllers/role.controller";

import { decodeToken } from "../middlewares/auth.middleware";
import {
  requireAuth,
  requireRole,
  requirePermission,
} from "../middlewares/authorization.middleware";

export const roleRouter = Router();

roleRouter.get(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("roles.ver"),
  getRoles
);

roleRouter.get(
  "/:id",
  decodeToken,
  requireAuth,
  requirePermission("roles.ver"),
  getRolById
);

roleRouter.post(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("roles.crear"),
  auditMiddleware("usuarios"),
  postRol
);

roleRouter.put(
  "/:id",
  decodeToken,
  requireAuth,
  requirePermission("roles.editar"),
  auditMiddleware("usuarios"),
  putRol
);

roleRouter.patch(
  "/:id/estado",
  decodeToken,
  requireAuth,
  requirePermission("roles.editar"),
  auditMiddleware("usuarios"),
  patchRolEstado
);

roleRouter.delete(
  "/:id",
  decodeToken,
  requireAuth,
  requireRole("ADMINISTRADOR"),
  auditMiddleware("usuarios"),
  deleteRol
);