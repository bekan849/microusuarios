import { Request, Response, NextFunction, RequestHandler } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env";

type TokenPayload = {
  idusuario: string;
  uidauth?: string;
  email?: string;
  roles?: string[];
  permisos?: string[];
};

type AuthenticatedRequest = Request & {
  user?: {
    idusuario: string;
    email?: string;
    roles?: string[];
    permisos?: string[];
  };
};

export const decodeToken: RequestHandler = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const auth = req.headers.authorization;

    if (!auth) {
      return res.status(401).json({
        ok: false,
        message: "Sin token",
      });
    }

    const [scheme, token] = auth.split(" ");

    if (scheme !== "Bearer" || !token) {
      return res.status(401).json({
        ok: false,
        message: "Formato de token inválido",
      });
    }

    const decoded = jwt.verify(token, env.JWT_SECRET) as TokenPayload;

    (req as AuthenticatedRequest).user = {
      idusuario: decoded.idusuario,
      email: decoded.email,
      roles: decoded.roles ?? [],
      permisos: decoded.permisos ?? [],
    };

    return next();
  } catch (err) {
    return res.status(401).json({
      ok: false,
      message: "Token inválido o expirado",
    });
  }
};