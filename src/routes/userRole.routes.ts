import { Router } from "express";
import {
  getRolesDeUsuario,
  getUsuariosDeRol,
  postUsuarioRol,
  patchUsuarioRolEstado,
  deleteUsuarioRol,
} from "../controllers/userRole.controller";

import { decodeToken } from "../middlewares/auth.middleware";
import {
  requireAuth,
  requirePermission,
} from "../middlewares/authorization.middleware";

export const userRoleRouter = Router();

userRoleRouter.get(
  "/usuario/:idusuario",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.ver"),
  getRolesDeUsuario
);

userRoleRouter.get(
  "/rol/:idrol",
  decodeToken,
  requireAuth,
  requirePermission("roles.ver"),
  getUsuariosDeRol
);

userRoleRouter.post(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.editar"),
  postUsuarioRol
);

userRoleRouter.patch(
  "/:idusuariorol/estado",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.editar"),
  patchUsuarioRolEstado
);

userRoleRouter.delete(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.editar"),
  deleteUsuarioRol
);