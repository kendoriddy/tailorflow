import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { handleCorsPreflight, jsonResponse } from "../_shared/cors.ts";
import {
  planAmountKobo,
  planPaystackCode,
  paystackRequest,
  type SubscriptionPlan,
} from "../_shared/paystack.ts";
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
    const planMonthly = Deno.env.get("PAYSTACK_PLAN_MONTHLY");
    const planYearly = Deno.env.get("PAYSTACK_PLAN_YEARLY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    if (!secretKey || !planMonthly || !planYearly || !supabaseUrl) {
      throw new Error("Paystack is not configured on the server");
    }

    const { plan } = (await req.json()) as { plan?: SubscriptionPlan };
    if (plan !== "monthly" && plan !== "yearly") {
      throw new Error('Invalid plan. Use "monthly" or "yearly".');
    }

    const userSb = userClient(authHeader);
    const { data: userData, error: userErr } = await userSb.auth.getUser();
    if (userErr || !userData.user?.email) {
      throw new Error("Signed-in user email is required for Paystack");
    }

    const shopId = await resolveShopId(userSb);
    const amount = planAmountKobo(plan);
    const paystackPlan = planPaystackCode(plan, planMonthly, planYearly);
    const reference = `tf_${shopId.replace(/-/g, "").slice(0, 12)}_${Date.now()}`;

    const callbackUrl = `${supabaseUrl}/functions/v1/paystack-return?reference=${reference}`;

    const initBody = await paystackRequest<{
      data: {
        authorization_url: string;
        access_code: string;
        reference: string;
      };
    }>(secretKey, "/transaction/initialize", {
      method: "POST",
      body: JSON.stringify({
        email: userData.user.email,
        amount: String(amount),
        plan: paystackPlan,
        reference,
        callback_url: callbackUrl,
        metadata: {
          shop_id: shopId,
          user_id: userData.user.id,
          plan,
          custom_fields: [
            {
              display_name: "Shop ID",
              variable_name: "shop_id",
              value: shopId,
            },
            { display_name: "Plan", variable_name: "plan", value: plan },
          ],
        },
      }),
    });

    const admin = serviceClient();
    const { error: insertErr } = await admin
      .from("paystack_checkout_sessions")
      .insert({
        shop_id: shopId,
        user_id: userData.user.id,
        reference,
        plan,
        amount_kobo: amount,
        status: "pending",
      });
    if (insertErr) throw insertErr;

    return jsonResponse({
      authorization_url: initBody.data.authorization_url,
      reference: initBody.data.reference,
      access_code: initBody.data.access_code,
      plan,
      amount_kobo: amount,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return jsonResponse({ error: message }, 400);
  }
});
