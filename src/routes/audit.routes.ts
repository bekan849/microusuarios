import { Router } from "express";
import { decodeToken } from "../middlewares/auth.middleware";
import { requirePermission } from "../middlewares/authorization.middleware";
import { auditFilters, listAudit, auditResponsibleNames } from "../services/audit.service";

export const auditRouter = Router();
auditRouter.get("/responsables", decodeToken, requirePermission("auditoria.ver"), async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  if (typeof req.query.ids !== "string") return res.status(400).json({ ok: false, message: "Identificadores inválidos" });
  const ids = req.query.ids.split(",");
  if (ids.length > 25 || ids.some(id => !id || id.length > 100)) return res.status(400).json({ ok: false, message: "Identificadores inválidos" });
  try { return res.json({ ok: true, data: await auditResponsibleNames(ids) }); }
  catch (err) { return res.status(503).json({ ok: false, message: (err as Error).message }); }
});
auditRouter.get("/", decodeToken, requirePermission("auditoria.ver"), async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  try { auditFilters(req.query); }
  catch (err) { return res.status(400).json({ ok: false, message: (err as Error).message }); }
  try { return res.json({ ok: true, ...await listAudit("usuarios", req.query) }); }
  catch (err) { return res.status(503).json({ ok: false, message: (err as Error).message }); }
});
