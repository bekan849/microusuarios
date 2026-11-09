import { supabaseAdmin } from '../lib/supabase';
import { requireEmpresaContext } from '../lib/empresa-context';

export class CalendarError extends Error {
  constructor(message: string, public status: number) { super(message); }
}
const fields = 'id,titulo,descripcion,inicio,fin,todo_el_dia,tipo,version';
const levels = ['General', 'Pendiente', 'Completado', 'Importante'];
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function date(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?(Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(Date.parse(value)))
    throw new CalendarError('Fecha y hora inválidas', 400);
  const day = value.slice(0,10);
  if (new Date(day + 'T00:00:00Z').toISOString().slice(0,10) !== day)
    throw new CalendarError('Fecha inexistente', 400);
  return new Date(value).toISOString();
}
export function calendarInput(input: unknown) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new CalendarError('Evento inválido', 400);
  const b = input as Record<string, unknown>;
  if (typeof b.titulo !== 'string' || !b.titulo.trim() || b.titulo.trim().length > 160 ||
      typeof b.descripcion !== 'string' || b.descripcion.length > 2000 || typeof b.todo_el_dia !== 'boolean' ||
      typeof b.tipo !== 'string' || !levels.includes(b.tipo)) throw new CalendarError('Revisa el título, descripción y tipo del evento', 400);
  const inicio = date(b.inicio), fin = date(b.fin);
  if (fin <= inicio) throw new CalendarError('El final debe ser posterior al inicio', 400);
  if (b.todo_el_dia && (!inicio.endsWith('T00:00:00.000Z') || !fin.endsWith('T00:00:00.000Z')))
    throw new CalendarError('Los eventos de día completo deben usar fechas sin hora', 400);
  return { titulo: b.titulo.trim(), descripcion: b.descripcion.trim(), inicio, fin, todo_el_dia: b.todo_el_dia, tipo: b.tipo };
}
export function calendarRange(input: Record<string, unknown>) {
  const desde = date(input.desde), hasta = date(input.hasta);
  if (hasta <= desde || Date.parse(hasta) - Date.parse(desde) > 370 * 86400000)
    throw new CalendarError('Consulta un rango de hasta 370 días', 400);
  return { desde, hasta };
}
function identity(id: string, version: unknown) {
  if (!uuid.test(id) || !Number.isInteger(version) || Number(version) < 1)
    throw new CalendarError('Identificador o versión inválidos', 400);
}
export async function listCalendar(input: Record<string, unknown>) {
  const { desde, hasta } = calendarRange(input);
  const { idusuario } = requireEmpresaContext();
  // Explicit paging avoids Supabase's default row cap silently dropping events.
  const result: Record<string, unknown>[] = [];
  for (let offset = 0; ; offset += 500) {
    const { data, error } = await supabaseAdmin.from('calendario_eventos').select(fields)
      .eq('idusuario', idusuario).lt('inicio', hasta).gt('fin', desde)
      .order('inicio').order('id').range(offset, offset + 499);
    if (error) throw new CalendarError('No se pudo cargar el calendario', 503);
    result.push(...(data ?? []));
    if (!data || data.length < 500) return result;
  }
}
export async function saveCalendar(input: unknown, id?: string) {
  const values = calendarInput(input);
  const { idusuario } = requireEmpresaContext();
  const version = (input as Record<string,unknown>).version;
  if (id) identity(id, version);
  const q = id
    ? supabaseAdmin.from('calendario_eventos').update({ ...values, version: Number(version) + 1 })
      .eq('id', id).eq('idusuario', idusuario).eq('version', version)
    : supabaseAdmin.from('calendario_eventos').insert({ ...values, idusuario });
  const { data, error } = await q.select(fields).maybeSingle();
  if (error) throw new CalendarError('No se pudo guardar el evento', 503);
  if (!data) throw new CalendarError('El evento cambió o ya no está disponible. Actualiza el calendario.', 409);
  return data;
}
export async function deleteCalendar(id: string, version: unknown) {
  identity(id, version);
  const { idusuario } = requireEmpresaContext();
  const { data, error } = await supabaseAdmin.from('calendario_eventos').delete()
    .eq('id', id).eq('idusuario', idusuario).eq('version', version).select('id').maybeSingle();
  if (error) throw new CalendarError('No se pudo eliminar el evento', 503);
  if (!data) throw new CalendarError('El evento cambió o ya no está disponible. Actualiza el calendario.', 409);
}
