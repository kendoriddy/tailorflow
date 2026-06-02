import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import {
  activateShopSubscription,
  deactivateShopSubscription,
  periodEndFromPlan,
} from "../_shared/activate.ts";
import {
  verifyPaystackSignature,
  type SubscriptionPlan,
} from "../_shared/paystack.ts";
import { serviceClient } from "../_shared/supabase.ts";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const secretKey = Deno.env.get("PAYSTACK_SECRET_KEY");
  if (!secretKey) {
    return new Response("Not configured", { status: 500 });
  }

  const rawBody = await req.text();
  const signature = req.headers.get("x-paystack-signature");
  const valid = await verifyPaystackSignature(secretKey, rawBody, signature);
  if (!valid) {
    return new Response("Invalid signature", { status: 401 });
  }

  const event = JSON.parse(rawBody) as {
    event: string;
    data: Record<string, unknown>;
  };

  const admin = serviceClient();

  try {
    const data = event.data;

    const shopIdFromMeta = (): string | null => {
      const meta = data.metadata as Record<string, unknown> | undefined;
      const custom = meta?.custom_fields as
        | Array<{
            variable_name?: string;
            value?: string;
          }>
        | undefined;
      if (typeof meta?.shop_id === "string") return meta.shop_id;
      const field = custom?.find((f) => f.variable_name === "shop_id");
      return field?.value ?? null;
    };

    switch (event.event) {
      case "charge.success": {
        const reference = data.reference as string | undefined;
        const status = data.status as string | undefined;
        if (!reference || status !== "success") break;

        const { data: session } = await admin
          .from("paystack_checkout_sessions")
          .select("shop_id, plan")
          .eq("reference", reference)
          .maybeSingle();

        const shopId = session?.shop_id ?? shopIdFromMeta();
        if (!shopId) break;

        const plan = (session?.plan ?? "monthly") as SubscriptionPlan;
        const customer = data.customer as
          | { customer_code?: string }
          | undefined;
        const sub = data.subscription as
          | { subscription_code?: string }
          | undefined;

        await activateShopSubscription(admin, {
          shopId,
          plan,
          paystackCustomerCode: customer?.customer_code ?? null,
          paystackSubscriptionCode: sub?.subscription_code ?? null,
          periodEnd: periodEndFromPlan(plan),
        });

        await admin
          .from("paystack_checkout_sessions")
          .update({
            status: "completed",
            completed_at: new Date().toISOString(),
          })
          .eq("reference", reference);
        break;
      }

      case "subscription.create":
      case "subscription.not_renew": {
        const shopId = shopIdFromMeta();
        if (!shopId) break;
        const planCode = (data.plan as { plan_code?: string })?.plan_code ?? "";
        const plan: SubscriptionPlan = planCode.toLowerCase().includes("year")
          ? "yearly"
          : "monthly";
        const subCode = data.subscription_code as string | undefined;
        const customer = data.customer as
          | { customer_code?: string }
          | undefined;
        const nextPayment = data.next_payment_date as string | undefined;

        await activateShopSubscription(admin, {
          shopId,
          plan,
          paystackSubscriptionCode: subCode ?? null,
          paystackCustomerCode: customer?.customer_code ?? null,
          periodEnd: nextPayment ?? periodEndFromPlan(plan),
        });
        break;
      }

      case "subscription.disable":
      case "invoice.payment_failed": {
        const customer = data.customer as
          | { customer_code?: string }
          | undefined;
        if (!customer?.customer_code) break;
        const { data: shops } = await admin
          .from("shops")
          .select("id")
          .eq("paystack_customer_code", customer.customer_code)
          .limit(1);
        const shopId = shops?.[0]?.id as string | undefined;
        if (!shopId) break;
        await deactivateShopSubscription(
          admin,
          shopId,
          event.event === "invoice.payment_failed" ? "past_due" : "cancelled",
        );
        break;
      }

      default:
        break;
    }
  } catch (e) {
    console.error("paystack-webhook error", e);
    return new Response("Webhook handler error", { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
