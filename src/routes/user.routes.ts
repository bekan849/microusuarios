import { auditMiddleware } from "../middlewares/audit.middleware";
import { Router } from "express";
import {
  getUsuarios,
  getUsuario,
  getAccesosUsuario,
  postUsuario,
  putUsuario,
  patchUsuarioEstado,
  deleteUsuario,
  patchUsuarioPassword,
} from "../controllers/user.controller";

import { decodeToken } from "../middlewares/auth.middleware";
import {
  requireAuth,
  requirePermission,
  requireRole,
} from "../middlewares/authorization.middleware";

export const userRouter = Router();

userRouter.get(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.ver"),
  getUsuarios
);

userRouter.get(
  "/:id/accesos",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.ver"),
  getAccesosUsuario
);

userRouter.get(
  "/:id",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.ver"),
  getUsuario
);

userRouter.post(
  "/",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.crear"),
  auditMiddleware("usuarios"),
  postUsuario
);

userRouter.put(
  "/:id",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.editar"),
  auditMiddleware("usuarios"),
  putUsuario
);

userRouter.patch(
  "/:id/estado",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.editar"),
  auditMiddleware("usuarios"),
  patchUsuarioEstado
);

userRouter.delete(
  "/:id",
  decodeToken,
  requireAuth,
  requireRole("ADMINISTRADOR"),
  auditMiddleware("usuarios"),
  deleteUsuario
);

userRouter.patch(
  "/:id/password",
  decodeToken,
  requireAuth,
  requirePermission("usuarios.editar"),
  auditMiddleware("usuarios"),
  patchUsuarioPassword
);