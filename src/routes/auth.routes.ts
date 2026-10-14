import { auditMiddleware } from '../middlewares/audit.middleware';
import { Router, type RequestHandler } from 'express';
import { postLogin, getAuthMe } from '../controllers/auth.controller';
import { decodeIdentity, decodeToken } from '../middlewares/auth.middleware';
import { listarEmpresas } from '../services/empresa.service';
import { seleccionarEmpresa } from '../services/auth.service';
import { empresaContext } from '../lib/empresa-context';

export const authRouter = Router();
const prepararSeleccion: RequestHandler = async (req,res,next) => {
  try {
    const data=await seleccionarEmpresa(req.user!.idusuario,String(req.body?.idempresa??''));
    res.locals.sesionEmpresa=data;
    res.locals.auditActor=data.usuario;
    empresaContext.run({idempresa:data.empresa!.idempresa,idusuario:data.usuario.idusuario,
      permisos:data.permisos.map(p=>p.codigo)},next);
  }catch{res.status(403).json({ok:false,message:'No tienes acceso a esa empresa'});}
};
authRouter.post('/login',auditMiddleware('usuarios'),postLogin);
authRouter.get('/me',decodeToken,getAuthMe);
authRouter.get('/empresas',decodeIdentity,async(req,res)=>{
  try{res.json({ok:true,data:await listarEmpresas(req.user!.idusuario)});}
  catch{res.status(403).json({ok:false,message:'No tienes empresas habilitadas'});}
});
authRouter.post('/empresa',decodeIdentity,prepararSeleccion,auditMiddleware('usuarios'),(_req,res)=>res.json({ok:true,data:res.locals.sesionEmpresa}));
authRouter.post('/logout',decodeToken,auditMiddleware('usuarios'),(_req,res)=>res.json({ok:true,message:'Cierre de sesión registrado'}));
