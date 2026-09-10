const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require('typescript');
require.extensions['.ts']=(mod,file)=>mod._compile(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020,esModuleInterop:true}}).outputText,file);
process.env.SUPABASE_URL='https://example.invalid';process.env.SUPABASE_SERVICE_ROLE_KEY='test';process.env.SUPABASE_ANON_KEY='test';process.env.JWT_SECRET='audit-test';
require('dotenv').config=()=>({parsed:{}});
const {supabaseAdmin}=require('../src/lib/supabase.ts');
const {auditValues,auditFilters}=require('../src/services/audit.service.ts');
const {auditMiddleware}=require('../src/middlewares/audit.middleware.ts');
const express=require('express');
let events=[], snapshot=0, fail=false;
supabaseAdmin.from=table=>({
  insert: event=>({abortSignal:async()=>{if(!fail)events.push(event);return {error:fail?{message:'test'}:null};}}),
  select:()=>{const q={eq:()=>q,abortSignal:()=>q,maybeSingle:async()=>({data:{idproducto:'product',precioventa:++snapshot===1?10:12,password:'secret'},error:null})};return q;}
});
test('Audit sanitization excludes credentials at every supported depth',()=>{
  const result=auditValues({password:'secret',token:'secret',uidauth:'secret',email:'a@b.invalid',items:[{cantidad:2,password:'secret',access_token:'secret'}],usuario:{nombre:'Ana',password:'secret'}});
  assert.equal(JSON.stringify(result).includes('secret'),false);
  assert.equal(result.items[0].cantidad,2);
});
test('Filters reject invalid pages/dates and reversed ranges',()=>{
  for(const value of [0,-1,1.5,'abc',10001]) assert.throws(()=>auditFilters({page:value}));
  for(const value of ['2026-02-30','2026-13-01','no-date']) assert.throws(()=>auditFilters({desde:value}));
  assert.throws(()=>auditFilters({desde:'2026-09-10',hasta:'2026-09-01'}));
  assert.equal(auditFilters({page:'2',desde:'2026-09-10'}).page,2);
});
test('Authenticated action audit integration',async t=>{
  const app=express();app.use(express.json());
  const actor=(req,res,next)=>{req.user={idusuario:'trusted',email:'real@example.invalid'};next();};
  app.put('/api/productos/:id',actor,auditMiddleware('productos'),(req,res)=>res.json({ok:true,data:{idproducto:req.params.id,precioventa:12}}));
  app.delete('/api/productos/:id',actor,auditMiddleware('productos'),(req,res)=>res.json({ok:true}));
  app.post('/api/ventas/registrar-completa',actor,auditMiddleware('productos'),(req,res)=>res.status(400).json({ok:false,message:'secret-error'}));
  app.post('/api/auth/login',auditMiddleware('usuarios'),(req,res)=>{
    if(req.body.fail)return res.status(400).json({ok:false});
    res.locals.auditActor={idusuario:'verified',email:'verified@example.invalid'};
    return res.json({ok:true,data:{token:'token-secret',usuario:res.locals.auditActor}});
  });
  app.post('/api/auth/logout',actor,auditMiddleware('usuarios'),(req,res)=>res.json({ok:true}));
  const server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
  const base='http://127.0.0.1:'+server.address().port;
  const request=(path,method,body={})=>fetch(base+path,{method,headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  try {
    await t.test('Changes use the trusted actor and capture old/new price',async()=>{
      events=[];snapshot=0;
      const r=await request('/api/productos/product','PUT',{idusuario:'forged',password:'secret'});
      assert.equal(r.status,200);assert.equal(events.length,1);assert.equal(events[0].actor_id,'trusted');
      assert.equal(events[0].antes.precioventa,10);assert.equal(events[0].despues.precioventa,12);
      assert.equal(events[0].registro_id,'product');assert.equal(JSON.stringify(events).includes('secret'),false);
    });
    await t.test('Deletion preserves the old value and no invented new value',async()=>{
      events=[];await request('/api/productos/product','DELETE');
      assert.ok(events[0].antes);assert.equal(events[0].despues,null);assert.equal(events[0].accion,'eliminar');
    });
    await t.test('Failed operation never records a successful change or raw error',async()=>{
      events=[];await request('/api/ventas/registrar-completa','POST',{password:'secret'});
      assert.equal(events[0].resultado,'error');assert.equal(events[0].despues,null);assert.equal(JSON.stringify(events).includes('secret'),false);
    });
    await t.test('Login trusts controller identity and excludes returned token',async()=>{
      events=[];await request('/api/auth/login','POST',{email:'fake',password:'secret'});
      assert.equal(events[0].actor_id,'verified');assert.equal(events[0].accion,'iniciar_sesion');assert.equal(JSON.stringify(events).includes('secret'),false);
      events=[];await request('/api/auth/login','POST',{fail:true,email:'fake',password:'secret'});
      assert.equal(events[0].actor_id,null);assert.equal(events[0].actor_email,null);
    });
    await t.test('Explicit logout is recorded',async()=>{
      events=[];await request('/api/auth/logout','POST');assert.equal(events[0].accion,'cerrar_sesion');assert.equal(events[0].actor_id,'trusted');
    });
    await t.test('Audit outage does not misreport an already committed operation',async()=>{
      fail=true;const r=await request('/api/productos/product','PUT');
      assert.equal(r.status,200);assert.equal((await r.json()).ok,true);assert.equal(r.headers.get('x-audit-status'),'unavailable');fail=false;
    });
  }finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});

test('History endpoint enforces current permissions and read-only API',async t=>{
  const userService=require('../src/services/user.service.ts');
  userService.obtenerAccesosDeUsuario=async id=>({usuario:{idusuario:id},roles:[],permisos:id==='allowed'?[{codigo:'auditoria.ver'}]:[]});
  const jwt=require('jsonwebtoken');
  const {auditRouter}=require('../src/routes/audit.routes.ts');
  const app=express();app.use('/api/historial',auditRouter);
  const server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
  const base='http://127.0.0.1:'+server.address().port+'/api/historial';
  const token=id=>jwt.sign({idusuario:id,permisos:['auditoria.ver']},process.env.JWT_SECRET);
  try{
    assert.equal((await fetch(base)).status,401);
    assert.equal((await fetch(base,{headers:{Authorization:'Bearer '+token('revoked')}})).status,403);
    assert.equal((await fetch(base+'?page=abc',{headers:{Authorization:'Bearer '+token('allowed')}})).status,400);
    assert.equal((await fetch(base,{method:'DELETE',headers:{Authorization:'Bearer '+token('allowed')}})).status,404);
  }finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});

test('History queries isolate services and use Bolivia day boundaries',async()=>{
  const previous=supabaseAdmin.from;const calls=[];
  supabaseAdmin.from=table=>{
    calls.push(['from',table]);const q={};
    for(const key of ['select','eq','order','range','ilike','gte','lt'])q[key]=(...args)=>{calls.push([key,...args]);return q;};
    q.abortSignal=async()=>({data:[],count:0,error:null});return q;
  };
  try{
    const {listAudit}=require('../src/services/audit.service.ts');
    const result=await listAudit('productos',{page:2,desde:'2026-09-10',hasta:'2026-09-10',usuario:'ana',accion:'editar'});
    assert.ok(calls.some(c=>c[0]==='eq'&&c[1]==='servicio'&&c[2]==='productos'));
    assert.ok(calls.some(c=>c[0]==='range'&&c[1]===25&&c[2]===49));
    assert.ok(calls.some(c=>c[0]==='gte'&&c[2]==='2026-09-10T00:00:00-04:00'));
    assert.ok(calls.some(c=>c[0]==='lt'&&c[2]==='2026-09-11T04:00:00.000Z'));
    assert.equal(result.total,0);
  }finally{supabaseAdmin.from=previous;}
});

test('Every existing mutation route in both services has auditing',()=>{
  const path=require('node:path');
  for(const root of [path.resolve(__dirname,'..'),path.resolve(__dirname,'../../microproductos')]){
    const dir=path.join(root,'src/routes');
    for(const file of fs.readdirSync(dir)){
      const source=fs.readFileSync(path.join(dir,file),'utf8');
      for(const match of source.matchAll(/\w+Router\.(post|put|patch|delete)\([\s\S]*?\);/g))assert.match(match[0],/auditMiddleware\(/,file+' is missing auditing');
    }
  }
});
