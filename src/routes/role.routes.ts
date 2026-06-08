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
  postRol
);

roleRouter.put(
  "/:id",
  decodeToken,
  requireAuth,
  requirePermission("roles.editar"),
  putRol
);

roleRouter.patch(
  "/:id/estado",
  decodeToken,
  requireAuth,
  requirePermission("roles.editar"),
  patchRolEstado
);

roleRouter.delete(
  "/:id",
  decodeToken,
  requireAuth,
  requireRole("ADMINISTRADOR"),
  deleteRol
);