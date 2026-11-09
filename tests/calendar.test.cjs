const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');
require.extensions['.ts'] = (mod, file) => mod._compile(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, esModuleInterop: true },
}).outputText, file);
process.env.SUPABASE_URL = 'https://example.invalid';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'test';
process.env.SUPABASE_ANON_KEY = 'test';
process.env.JWT_SECRET = 'test-calendar-only';
const { calendarInput, calendarRange } = require('../src/services/calendar.service.ts');
const valid = { titulo: 'Entrega', descripcion: 'Proveedor', inicio: '2026-11-09T00:00:00Z', fin: '2026-11-10T00:00:00Z', todo_el_dia: true, tipo: 'Pendiente' };

test('Valida fechas, rango, título y campos admitidos; fin es exclusivo', () => {
  assert.equal(calendarInput({ ...valid, idempresa: 'ajena', idusuario: 'ajeno', version: 3 }).idempresa, undefined);
  for (const changes of [{ titulo: '  ' }, { fin: valid.inicio }, { inicio: '2026-02-30T00:00:00Z' }, { todo_el_dia: 'true' }, { tipo: 'otro' }, { inicio: '2026-11-09T09:00:00Z' }])
    assert.throws(() => calendarInput({ ...valid, ...changes }));
  assert.throws(() => calendarRange({ desde: valid.fin, hasta: valid.inicio }));
  assert.throws(() => calendarRange({ desde: valid.inicio, hasta: '2028-01-01T00:00:00Z' }));
  assert.equal(calendarInput(valid).fin, '2026-11-10T00:00:00.000Z');
});

test('API: persistencia, aislamiento por usuario/empresa, conflictos y sesiones revocadas', async () => {
  const { supabaseSystem } = require('../src/lib/supabase.ts');
  const jwt = require('jsonwebtoken');
  const express = require('express');
  const { calendarRouter } = require('../src/routes/calendar.routes.ts');
  let active = true, nextId = 1;
  const uid='00000000-0000-0000-0000-000000000011', eid='00000000-0000-0000-0000-000000000021';
  const records = [];
  const auditRecords = [];
  supabaseSystem.rpc = async (_name, args) => active ? { data: { usuario: {idusuario:args.p_idusuario}, empresa: {idempresa:args.p_idempresa}, roles: [], permisos: [] }, error: null } : { data: null, error: { message: 'revocada' } };
  supabaseSystem.from = table => {
    if (table === 'historial_acciones') return { insert: record => ({ abortSignal: async () => { auditRecords.push(record); return {error:null}; } }) };
    if (table === 'usuarios') { const q = { select:()=>q, eq:()=>q, in:()=>q, abortSignal:async()=>({data:[],error:null}) };return q; }
    assert.equal(table, 'calendario_eventos');
    const filters = []; let action = 'select', values, range, columns;
    const q = {
      select(c) { columns=c; return q; }, insert(v) { action = 'insert'; values = v; return q; }, abortSignal() { return q; },
      update(v) { action = 'update'; values = v; return q; }, delete() { action = 'delete'; return q; },
      eq(k,v) { filters.push(r=>r[k]===v); return q; }, lt(k,v) { filters.push(r=>r[k]<v); return q; }, gt(k,v) { filters.push(r=>r[k]>v); return q; },
      order() { return q; }, range(a,b) { range=[a,b]; return q; },
      run() {
        if (action==='insert') { const row = { ...values, id: `00000000-0000-0000-0000-${String(nextId++).padStart(12,'0')}`, version: 1 }; records.push(row); return [row]; }
        let found = records.filter(r=>filters.every(f=>f(r)));
        if (action==='update') found.forEach(r=>Object.assign(r,values));
        if (action==='delete') found.forEach(r=>records.splice(records.indexOf(r),1));
        if (range) found=found.slice(range[0],range[1]+1);
        return found.map(r=>columns==='idusuario'?{idusuario:r.idusuario}:({...r}));
      },
      async maybeSingle() { return {data:q.run()[0]??null,error:null}; },
      then(resolve,reject) { return Promise.resolve({data:q.run(),error:null}).then(resolve,reject); },
    };return q;
  };
  const app=express();app.use(express.json());app.use('/api/calendario',calendarRouter);
  const server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
  const base=`http://127.0.0.1:${server.address().port}/api/calendario`;
  const token=(user=uid,company=eid,tipo='empresa')=>jwt.sign({version:2,tipo,idusuario:user,idempresa:company},process.env.JWT_SECRET,{expiresIn:'1h'});
  async function call(method,path='',body,auth=token()) {const res=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+auth}:{})},...(body?{body:JSON.stringify(body)}:{})});return {status:res.status,body:await res.json()};}
  const range='?desde=2026-11-01T00:00:00Z&hasta=2026-12-01T00:00:00Z';
  try {
    assert.equal((await call('GET',range,undefined,'')).status,401);
    assert.equal((await call('GET',range,undefined,token(uid,eid,'seleccion_empresa'))).status,403);
    const created=await call('POST','',{...valid,idusuario:'u2',idempresa:'e2'});assert.equal(created.status,201);
    const event=created.body.data;assert.equal(records[0].idusuario,uid);assert.equal(records[0].idempresa,eid);
    assert.equal((await call('GET',range)).body.data.length,1);
    for (const auth of [token('00000000-0000-0000-0000-000000000012'),token(uid,'00000000-0000-0000-0000-000000000022')]) {
      assert.deepEqual((await call('GET',range,undefined,auth)).body.data,[]);
      assert.equal((await call('PUT','/'+event.id,{...valid,version:1},auth)).status,409);
      assert.equal((await call('DELETE','/'+event.id,{version:1},auth)).status,409);
    }
    assert.equal((await call('PUT','/'+event.id,{...valid,titulo:'Editado',version:1})).status,200);
    assert.equal((await call('PUT','/'+event.id,{...valid,version:1})).status,409);
    assert.equal((await call('DELETE','/'+event.id,{version:1})).status,409);
    assert.equal((await call('GET',range)).body.data[0].titulo,'Editado');
    active=false;assert.equal((await call('GET',range)).status,403);active=true;
    assert.equal((await call('DELETE','/'+event.id,{version:2})).status,200);
    assert.deepEqual((await call('GET',range)).body.data,[]);
    assert.ok(auditRecords.length > 0);
    assert.ok(auditRecords.every(r=>r.recurso==='calendario'));
    assert.ok(!JSON.stringify(auditRecords).includes('Proveedor'));
  } finally {server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
});

test('SQL: membresía obligatoria, restricciones y acceso exclusivo del backend', async () => {
  const { PGlite } = require('@electric-sql/pglite');
  const db = new PGlite();
  const id = '00000000-0000-0000-0000-000000000001';
  try {
    await db.exec('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE TABLE empresa_usuario(idempresa uuid,idusuario uuid,PRIMARY KEY(idempresa,idusuario));');
    await db.exec(fs.readFileSync(require('node:path').join(__dirname,'../supabase/migrations/202611090001_calendario_personal.sql'),'utf8'));
    await db.exec(`INSERT INTO empresa_usuario VALUES ('${id}','${id}'); SET ROLE service_role;`);
    const insert=`INSERT INTO calendario_eventos(idempresa,idusuario,titulo,inicio,fin,todo_el_dia,tipo) VALUES ('${id}','${id}','Entrega','2026-11-09T00:00:00Z','2026-11-10T00:00:00Z',true,'General')`;
    await db.exec(insert);
    await assert.rejects(()=>db.exec(insert.replace('2026-11-10','2026-11-08')),/check constraint/);
    await assert.rejects(()=>db.exec(insert.replaceAll(id,'00000000-0000-0000-0000-000000000099')),/foreign key/);
    await db.exec('RESET ROLE');
    for (const role of ['anon','authenticated']) {
      await db.exec('SET ROLE '+role);
      await assert.rejects(()=>db.query('SELECT * FROM calendario_eventos'),/permission denied/);
      await assert.rejects(()=>db.exec(insert),/permission denied/);
      await db.exec('RESET ROLE');
    }
  } finally {await db.close();}
});
