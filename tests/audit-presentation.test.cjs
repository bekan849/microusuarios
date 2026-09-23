const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),ts=require('typescript');
require.extensions['.ts']=(mod,file)=>mod._compile(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,file);
const {auditComparison}=require('C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/utils/audit-presentation.ts');
const base={accion:'editar',recurso:'marcas',resultado:'exito',antes:null,despues:null,detalles:{}};
test('Brand comparison includes changed and unchanged recorded fields',()=>{
  const r=auditComparison({...base,antes:{nombre:'A',estado:true},despues:{nombre:'B',estado:true}});
  assert.equal(r.rows.length,2);assert.equal(r.rows[0].before,'A');assert.equal(r.rows[0].after,'B');assert.equal(r.rows[0].changed,true);assert.equal(r.rows[1].changed,false);
});
test('Identical values are displayed rather than reported missing',()=>{
  const r=auditComparison({...base,antes:{nombre:'A'},despues:{nombre:'A'}});
  assert.equal(r.rows.length,1);assert.match(r.message,/iguales/);
});
test('Missing old values never become invented historical values',()=>{
  const r=auditComparison({...base,despues:{nombre:'B'}});assert.equal(r.rows[0].before,'No registrado');
  assert.match(auditComparison(base).message,/no guardó/);
});
test('Login reports the outcome without fabricating a previous session state',()=>{
  const r=auditComparison({...base,accion:'iniciar_sesion',recurso:'auth'});
  assert.match(r.rows[0].before,/No aplica/);assert.equal(r.rows[0].after,'Inicio de sesión exitoso');
  assert.match(auditComparison({...base,accion:'iniciar_sesion',recurso:'auth',resultado:'error'}).rows[0].after,/rechazado/);
});
test('Creation and physical removal have explicit absence labels',()=>{
  assert.equal(auditComparison({...base,accion:'crear',despues:{nombre:'A'},detalles:{registro_creado:true}}).rows[0].before,'No existía');
  assert.equal(auditComparison({...base,accion:'eliminar',antes:{nombre:'A'},detalles:{registro_eliminado:true}}).rows[0].after,'Registro eliminado');
});
test('Passwords are always hidden and legacy serialized values remain readable',()=>{
  const r=auditComparison({...base,accion:'cambiar_password',antes:{password:'secret'},despues:{password:'secret2'}});
  assert.equal(JSON.stringify(r).includes('secret'),false);
  assert.equal(auditComparison({...base,antes:'{"nombre":"A"}',despues:'{"nombre":"B"}'}).rows[0].after,'B');
});
