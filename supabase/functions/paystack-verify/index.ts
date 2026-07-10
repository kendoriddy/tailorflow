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

async function currentSubscriptionPayload(
  admin: ReturnType<typeof serviceClient>,
  shopId: string,
  fallbackPlan: SubscriptionPlan,
) {
  const { data: shop, error } = await admin
    .from("shops")
    .select("subscription_status, subscription_plan, subscription_period_end")
    .eq("id", shopId)
    .maybeSingle();
  if (error) throw error;

  const status = typeof shop?.subscription_status === "string"
    ? shop.subscription_status
    : "free";
  const periodEnd = typeof shop?.subscription_period_end === "string"
    ? shop.subscription_period_end
    : null;
  const storedPlan = shop?.subscription_plan;
  const plan: SubscriptionPlan = storedPlan === "monthly" ||
      storedPlan === "yearly"
    ? storedPlan
    : fallbackPlan;
  const periodEndTime = periodEnd ? Date.parse(periodEnd) : null;
  const active = status === "active" &&
    (!periodEndTime || periodEndTime > Date.now());

  return {
    active,
    plan,
    subscription_status: status,
    subscription_period_end: periodEnd,
  };
}

async function markCheckoutCompleted(
  admin: ReturnType<typeof serviceClient>,
  reference: string,
): Promise<void> {
  const { error } = await admin
    .from("paystack_checkout_sessions")
    .update({
      status: "completed",
      completed_at: new Date().toISOString(),
    })
    .eq("reference", reference);
  if (error) throw error;
}

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
    const admin = serviceClient();

    const { data: session, error: sessErr } = await admin
      .from("paystack_checkout_sessions")
      .select("plan, shop_id, status")
      .eq("reference", reference)
      .maybeSingle();
    if (sessErr) throw sessErr;
    if (!session) throw new Error("Checkout session not found");
    if (session.shop_id !== shopId) {
      throw new Error("Checkout session shop mismatch");
    }

    const sessionPlan = session.plan as SubscriptionPlan;
    if (sessionPlan !== "monthly" && sessionPlan !== "yearly") {
      throw new Error("Invalid checkout session plan");
    }
    if (session.status === "completed") {
      return jsonResponse(
        await currentSubscriptionPayload(admin, shopId, sessionPlan),
      );
    }
    if (session.status !== "pending") {
      throw new Error(`Checkout session is ${session.status}`);
    }

    const { data: processed, error: processedErr } = await admin
      .from("paystack_processed_payments")
      .select("reference")
      .eq("reference", reference)
      .maybeSingle();
    if (processedErr) throw processedErr;
    if (processed) {
      await markCheckoutCompleted(admin, reference);
      return jsonResponse(
        await currentSubscriptionPayload(admin, shopId, sessionPlan),
      );
    }

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

    const plan: SubscriptionPlan =
      sessionPlan ??
      data.metadata?.plan ??
      (data.plan?.interval === "annually" ? "yearly" : "monthly");
    const periodEnd = periodEndFromPlan(plan);

    await activateShopSubscription(admin, {
      shopId,
      plan,
      paystackSubscriptionCode: data.subscription?.subscription_code ?? null,
      paystackCustomerCode: data.customer?.customer_code ?? null,
      periodEnd,
    });

    await markCheckoutCompleted(admin, reference);

    return jsonResponse({
      active: true,
      plan,
      subscription_status: "active",
      subscription_period_end: periodEnd,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return jsonResponse({ error: message, active: false }, 400);
  }
});
