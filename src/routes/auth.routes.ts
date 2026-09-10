import { auditMiddleware } from "../middlewares/audit.middleware";
import { Router } from "express";
import { postLogin, getAuthMe } from "../controllers/auth.controller";
import { decodeToken } from "../middlewares/auth.middleware";

export const authRouter = Router();

authRouter.post("/login", auditMiddleware("usuarios"), postLogin);
authRouter.get("/me", decodeToken, getAuthMe);
authRouter.post("/logout", decodeToken, auditMiddleware("usuarios"), (_req, res) => res.json({ ok: true, message: "Cierre de sesión registrado" }));
