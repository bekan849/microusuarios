/** Solo usar el respaldo cuando PostgREST aún no conoce la migración. */
export function faltaFuncionRpc(error: { code?: string } | null): boolean {
  return error?.code === "PGRST202";
}
