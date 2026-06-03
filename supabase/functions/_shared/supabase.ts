import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Missing Supabase service configuration");
  return createClient(url, key, { auth: { persistSession: false } });
}

export function userClient(authHeader: string) {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!url || !anon) throw new Error("Missing Supabase anon configuration");
  return createClient(url, anon, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
}

export async function resolveShopId(
  client: ReturnType<typeof userClient>,
): Promise<string> {
  const { data: userData, error: userErr } = await client.auth.getUser();
  if (userErr || !userData.user) throw new Error("Not authenticated");

  await client.rpc("bootstrap_current_user_shop");

  const { data: rows, error } = await client
    .from("shop_memberships")
    .select("shop_id")
    .eq("user_id", userData.user.id)
    .limit(1);
  if (error) throw error;
  if (!rows?.length) throw new Error("No shop linked to this account");
  return rows[0].shop_id as string;
}
