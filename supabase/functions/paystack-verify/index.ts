import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { handleCorsPreflight, jsonResponse } from "../_shared/cors.ts";
import {
  activateShopSubscription,
  periodEndFromPlan,
} from "../_shared/activate.ts";
import { paystackRequest, type SubscriptionPlan } from "../_shared/paystack.ts";
import {
  resolveShopId,
  serviceClient,
  userClient,
} from "../_shared/supabase.ts";

serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing Authorization header");

    const secretKey = Deno.env.get("PAYSTACK_SECRET_KEY");
    if (!secretKey) throw new Error("Paystack is not configured on the server");

    const { reference } = (await req.json()) as { reference?: string };
    if (!reference?.trim()) throw new Error("reference is required");

    const userSb = userClient(authHeader);
    const shopId = await resolveShopId(userSb);

    const verify = await paystackRequest<{
      data: {
        status: string;
        reference: string;
        metadata?: { shop_id?: string; plan?: SubscriptionPlan };
        customer?: { customer_code?: string };
        plan?: { plan_code?: string; interval?: string };
        subscription?: { subscription_code?: string };
      };
    }>(secretKey, `/transaction/verify/${encodeURIComponent(reference)}`);

    const data = verify.data;
    if (data.status !== "success") {
      throw new Error(`Payment not successful (${data.status})`);
    }

    const metaShop = data.metadata?.shop_id;
    if (metaShop && metaShop !== shopId) {
      throw new Error("Payment does not belong to this shop");
    }

    const admin = serviceClient();

    const { data: session, error: sessErr } = await admin
      .from("paystack_checkout_sessions")
      .select("plan, shop_id")
      .eq("reference", reference)
      .maybeSingle();
    if (sessErr) throw sessErr;

    const plan: SubscriptionPlan =
      session?.plan ??
      data.metadata?.plan ??
      (data.plan?.interval === "annually" ? "yearly" : "monthly");

    if (session?.shop_id && session.shop_id !== shopId) {
      throw new Error("Checkout session shop mismatch");
    }

    await activateShopSubscription(admin, {
      shopId,
      plan,
      paystackSubscriptionCode: data.subscription?.subscription_code ?? null,
      paystackCustomerCode: data.customer?.customer_code ?? null,
      periodEnd: periodEndFromPlan(plan),
    });

    await admin
      .from("paystack_checkout_sessions")
      .update({
        status: "completed",
        completed_at: new Date().toISOString(),
      })
      .eq("reference", reference);

    return jsonResponse({
      active: true,
      plan,
      subscription_status: "active",
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return jsonResponse({ error: message, active: false }, 400);
  }
});
