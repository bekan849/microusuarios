import { Router, type RequestHandler } from 'express';
import { decodeToken } from '../middlewares/auth.middleware';
import { auditMiddleware } from '../middlewares/audit.middleware';
import { CalendarError, deleteCalendar, listCalendar, saveCalendar } from '../services/calendar.service';

export const calendarRouter = Router();
calendarRouter.use(decodeToken);
calendarRouter.use((_req, res, next) => { res.setHeader('Cache-Control', 'no-store'); next(); });
const handle = (operation: RequestHandler): RequestHandler => async (req, res, next) => {
  try { await operation(req, res, next); }
  catch (e) {
    res.status(e instanceof CalendarError ? e.status : 503).json({ ok: false,
      message: e instanceof CalendarError ? e.message : 'Calendario no disponible' });
  }
};
calendarRouter.get('/', handle(async (req, res) => { res.json({ ok: true, data: await listCalendar(req.query) }); }));
calendarRouter.post('/', auditMiddleware('usuarios'), handle(async (req, res) => { res.status(201).json({ ok: true, data: await saveCalendar(req.body) }); }));
calendarRouter.put('/:id', auditMiddleware('usuarios'), handle(async (req, res) => { res.json({ ok: true, data: await saveCalendar(req.body, String(req.params.id)) }); }));
calendarRouter.delete('/:id', auditMiddleware('usuarios'), handle(async (req, res) => { await deleteCalendar(String(req.params.id), req.body?.version); res.json({ ok: true }); }));
