import { Router } from "express";
import { postLogin, getAuthMe } from "../controllers/auth.controller";
import { decodeToken } from "../middlewares/auth.middleware";

export const authRouter = Router();

authRouter.post("/login", postLogin);
authRouter.get("/me", decodeToken, getAuthMe);