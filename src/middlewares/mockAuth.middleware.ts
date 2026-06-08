import type { NextFunction, Request, Response } from "express";

export function mockAuth(req: Request, _res: Response, next: NextFunction) {
  const idusuario = req.header("x-idusuario");
  const email = req.header("x-email") ?? undefined;
  const uidauth = req.header("x-uidauth") ?? undefined;

  if (idusuario) {
    req.user = {
      idusuario,
      email,
      uidauth,
    };
  }

  next();
}