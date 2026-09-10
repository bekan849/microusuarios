import { Router } from "express";
import { decodeToken } from "../middlewares/auth.middleware";
import { requirePermission } from "../middlewares/authorization.middleware";
import { auditFilters, listAudit } from "../services/audit.service";

export const auditRouter = Router();
auditRouter.get("/", decodeToken, requirePermission("auditoria.ver"), async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  try { auditFilters(req.query); }
  catch (err) { return res.status(400).json({ ok: false, message: (err as Error).message }); }
  try { return res.json({ ok: true, ...await listAudit("usuarios", req.query) }); }
  catch (err) { return res.status(503).json({ ok: false, message: (err as Error).message }); }
});
