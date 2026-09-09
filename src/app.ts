import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";

import { env } from "./config/env";

import { healthRouter } from "./routes/health.routes";
import { authRouter } from "./routes/auth.routes";
import { userRouter } from "./routes/user.routes";
import { roleRouter } from "./routes/role.routes";
import { permissionRouter } from "./routes/permission.routes";
import { rolePermissionRouter } from "./routes/rolePermission.routes";
import { userRoleRouter } from "./routes/userRole.routes";

import { notFound } from "./middlewares/notFound.middleware";
import { errorMiddleware } from "./middlewares/error.middleware";

export const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const allowedOrigins = new Set([
  "http://localhost:5173",
  "https://sis-stockf.onrender.com",
  ...env.CORS_ORIGIN.split(",").map((origin) => origin.trim()).filter((origin) => origin && origin !== "*"),
]);

app.use(
  cors({
    origin(origin, callback) {
      if (!origin || allowedOrigins.has(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error("No permitido por CORS"));
    },
    credentials: true,
    maxAge: 600,
  })
);

app.use(helmet());
if (env.NODE_ENV !== "production") app.use(morgan("dev"));

/* rutas públicas */
app.use("/api/health", healthRouter);
app.use("/api/auth", authRouter);

/* rutas privadas */
app.use("/api/usuarios", userRouter);
app.use("/api/roles", roleRouter);
app.use("/api/permisos", permissionRouter);
app.use("/api/rol-permiso", rolePermissionRouter);
app.use("/api/usuario-rol", userRoleRouter);

/* middlewares */
app.use(notFound);
app.use(errorMiddleware);
