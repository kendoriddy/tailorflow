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

function normalizedPlan(raw: unknown): SubscriptionPlan | null {
  return raw === "monthly" || raw === "yearly" ? raw : null;
}

function planFromPaystackData(
  data: Record<string, unknown>,
): SubscriptionPlan | null {
  const metadata = data.metadata as Record<string, unknown> | undefined;
  const metaPlan = normalizedPlan(metadata?.plan);
  if (metaPlan) return metaPlan;

  const plan = data.plan as
    { interval?: string; plan_code?: string } | undefined;
  const interval = plan?.interval?.toLowerCase();
  if (interval?.includes("year") || interval === "annually") return "yearly";
  if (interval?.includes("month")) return "monthly";

  const planCode = plan?.plan_code?.toLowerCase() ?? "";
  if (planCode.includes("year")) return "yearly";
  if (planCode.includes("month")) return "monthly";
  return null;
}

function nextPaymentDateFromPaystackData(
  data: Record<string, unknown>,
): string | null {
  if (typeof data.next_payment_date === "string") {
    return data.next_payment_date;
  }
  const subscription = data.subscription as
    { next_payment_date?: string } | undefined;
  return typeof subscription?.next_payment_date === "string"
    ? subscription.next_payment_date
    : null;
}

async function findShopByPaystackCodes(
  admin: ReturnType<typeof serviceClient>,
  subscriptionCode?: string,
  customerCode?: string,
): Promise<{ id: string; subscription_plan: string | null } | null> {
  if (subscriptionCode) {
    const { data: shop, error } = await admin
      .from("shops")
      .select("id, subscription_plan")
      .eq("paystack_subscription_code", subscriptionCode)
      .maybeSingle();
    if (error) throw error;
    if (shop) return shop as { id: string; subscription_plan: string | null };
  }

  if (customerCode) {
    const { data: shop, error } = await admin
      .from("shops")
      .select("id, subscription_plan")
      .eq("paystack_customer_code", customerCode)
      .maybeSingle();
    if (error) throw error;
    if (shop) return shop as { id: string; subscription_plan: string | null };
  }

  return null;
}

async function activateProcessedPayment(
  admin: ReturnType<typeof serviceClient>,
  params: {
    reference: string;
    shopId: string;
    event: string;
    plan: SubscriptionPlan;
    paystackSubscriptionCode?: string | null;
    paystackCustomerCode?: string | null;
    periodEnd: string;
  },
): Promise<boolean> {
  const { data, error } = await admin.rpc(
    "activate_paystack_processed_payment",
    {
      p_reference: params.reference,
      p_shop_id: params.shopId,
      p_event: params.event,
      p_plan: params.plan,
      p_paystack_subscription_code: params.paystackSubscriptionCode ?? null,
      p_paystack_customer_code: params.paystackCustomerCode ?? null,
      p_period_end: params.periodEnd,
    },
  );
  if (!error) return data === true;
  throw error;
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

        const { data: session, error: sessionErr } = await admin
          .from("paystack_checkout_sessions")
          .select("shop_id, plan, status")
          .eq("reference", reference)
          .maybeSingle();
        if (sessionErr) throw sessionErr;
        if (session?.status === "completed") break;

        const customer = data.customer as
          { customer_code?: string } | undefined;
        const sub = data.subscription as
          { subscription_code?: string } | undefined;

        const codeShop =
          session || shopIdFromMeta()
            ? null
            : await findShopByPaystackCodes(
                admin,
                sub?.subscription_code,
                customer?.customer_code,
              );
        const shopId = session?.shop_id ?? shopIdFromMeta() ?? codeShop?.id;
        if (!shopId) break;

        const plan = (normalizedPlan(session?.plan) ??
          planFromPaystackData(data) ??
          normalizedPlan(codeShop?.subscription_plan) ??
          "monthly") as SubscriptionPlan;
        const periodEnd =
          nextPaymentDateFromPaystackData(data) ?? periodEndFromPlan(plan);

        const firstProcessing = await activateProcessedPayment(admin, {
          reference,
          shopId,
          event: event.event,
          plan,
          paystackCustomerCode: customer?.customer_code ?? null,
          paystackSubscriptionCode: sub?.subscription_code ?? null,
          periodEnd,
        });
        if (!firstProcessing) {
          if (session) await markCheckoutCompleted(admin, reference);
          break;
        }

        if (session) await markCheckoutCompleted(admin, reference);
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
          { customer_code?: string } | undefined;
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
          { customer_code?: string } | undefined;
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
