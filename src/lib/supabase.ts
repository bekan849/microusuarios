import { createClient } from "@supabase/supabase-js";
import { env } from "../config/env";
import { createEmpresaClient } from './empresa-client';

export const supabaseSystem = createClient(
  env.SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: { persistSession: false },
  }
);

export const supabaseAuth = createClient(
  env.SUPABASE_URL,
  env.SUPABASE_ANON_KEY,
  {
    auth: { persistSession: false },
  }
);

export const supabaseAdmin = createEmpresaClient(supabaseSystem);
