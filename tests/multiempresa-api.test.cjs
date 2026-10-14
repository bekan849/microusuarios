const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),ts=require('typescript');
require.extensions['.ts']=(mod,file)=>mod._compile(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020,esModuleInterop:true}}).outputText,file);
process.env.SUPABASE_URL='https://example.invalid';process.env.SUPABASE_SERVICE_ROLE_KEY='test';process.env.SUPABASE_ANON_KEY='test';process.env.JWT_SECRET='test-multiempresa';
const {createClient}=require('@supabase/supabase-js');
const {createEmpresaClient}=require('../src/lib/empresa-client.ts');
const {empresaContext}=require('../src/lib/empresa-context.ts');
const scope={idempresa:'00000000-0000-0000-0000-000000000010',idusuario:'00000000-0000-0000-0000-000000000001',permisos:['productos.ver']};

test('Cliente de negocio siempre limita consultas y mutaciones a la empresa verificada',async()=>{
 const calls=[];
 const raw=createClient('https://example.invalid','test',{global:{fetch:async(url,options)=>{calls.push({url:new URL(url),...options});return new Response('[]',{status:200,headers:{'Content-Type':'application/json'}});}}});
 const client=createEmpresaClient(raw);
 assert.throws(()=>client.from('productos').select('*'),/Selecciona una empresa/);
 await empresaContext.run(scope,async()=>{
   await client.from('productos').select('*').eq('idproducto','foreign');
   assert.equal(calls.at(-1).url.searchParams.get('idempresa'),'eq.'+scope.idempresa);
   await client.from('productos').update({nombre:'Nombre'}).eq('idproducto','foreign');
   assert.equal(calls.at(-1).url.searchParams.get('idempresa'),'eq.'+scope.idempresa);
   await client.from('productos').delete().eq('idproducto','foreign');
   assert.equal(calls.at(-1).url.searchParams.get('idempresa'),'eq.'+scope.idempresa);
   await client.from('compra').insert({idusuario:'forged',idproveedor:'supplier'});
   assert.equal(JSON.parse(calls.at(-1).body).idusuario,scope.idusuario);
   assert.equal(JSON.parse(calls.at(-1).body).idempresa,scope.idempresa);
   assert.throws(()=>client.from('productos').insert({idempresa:'foreign'}),/incompatible/);
   assert.throws(()=>client.from('productos').update({idempresa:'foreign'}),/trasladar/);
   assert.throws(()=>client.from('permisos').update({codigo:'root'}),/administrado/);
   assert.throws(()=>client.from('usuarios').delete(),/identidad compartida/);
   assert.throws(()=>client.from('otra_tabla'),/Tabla no habilitada/);
   assert.throws(()=>client.rpc('otra_funcion'),/RPC no habilitada/);
   await client.from('usuarios').select('idusuario,nombre');
   assert.match(calls.at(-1).url.searchParams.get('select'),/empresa_usuario!inner/);
   assert.equal(calls.at(-1).url.searchParams.get('__empresa.idempresa'),'eq.'+scope.idempresa);
   await client.rpc('registrar_venta_completa_atomica',{p_idempresa:'forged',p_idusuario:'forged',p_payload:{}});
   const rpc=JSON.parse(calls.at(-1).body);
   assert.equal(rpc.p_idempresa,scope.idempresa);assert.equal(rpc.p_idusuario,scope.idusuario);
   assert.match(calls.at(-1).url.pathname,/registrar_venta_empresa$/);
 });
});

test('Peticiones concurrentes conservan su propio contexto de empresa',async()=>{
 const seen=[];
 await Promise.all(['motos','bike'].map(idempresa=>empresaContext.run({...scope,idempresa},async()=>{
   await new Promise(resolve=>setTimeout(resolve,idempresa==='motos'?15:1));
   seen.push(empresaContext.getStore().idempresa);
 })));
 assert.deepEqual(seen,['bike','motos']);assert.equal(empresaContext.getStore(),undefined);
});

test('Sesiones antiguas y de selección no autorizan operaciones; se revalida membresía',async()=>{
 const jwt=require('jsonwebtoken');
 const {supabaseSystem}=require('../src/lib/supabase.ts');
 let active=true,calls=0;
 supabaseSystem.rpc=async(name,args)=>{
   calls++;assert.equal(name,'obtener_accesos_empresa');assert.equal(args.p_idempresa,scope.idempresa);
   return active?{data:{usuario:{idusuario:scope.idusuario},empresa:{idempresa:scope.idempresa},roles:[],permisos:[{codigo:'productos.ver'}]},error:null}:{data:null,error:{message:'revocada'}};
 };
 const {decodeToken}=require('../src/middlewares/auth.middleware.ts');
 const run=payload=>new Promise(resolve=>{
   const token=jwt.sign(payload,process.env.JWT_SECRET,{expiresIn:'1h'});
   const req={headers:{authorization:'Bearer '+token},body:{idempresa:'foreign'}};
   const res={status(code){this.code=code;return this;},json(body){resolve({status:this.code,body});}};
   decodeToken(req,res,()=>resolve({status:200,scope:empresaContext.getStore(),user:req.user}));
 });
 assert.equal((await run({idusuario:scope.idusuario})).status,401);
 assert.equal((await run({version:2,tipo:'seleccion_empresa',idusuario:scope.idusuario})).status,403);
 const payload={version:2,tipo:'empresa',idusuario:scope.idusuario,idempresa:scope.idempresa,permisos:['root']};
 const valid=await run(payload);assert.equal(valid.status,200);assert.equal(valid.scope.idempresa,scope.idempresa);assert.deepEqual(valid.user.permisos,['productos.ver']);
 active=false;assert.equal((await run(payload)).status,403);assert.equal(calls,2);
});
