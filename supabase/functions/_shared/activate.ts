import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import type { SubscriptionPlan } from "./paystack.ts";

export async function activateShopSubscription(
  admin: SupabaseClient,
  params: {
    shopId: string;
    plan: SubscriptionPlan;
    paystackSubscriptionCode?: string | null;
    paystackCustomerCode?: string | null;
    periodEnd?: string | null;
  },
): Promise<void> {
  const { error } = await admin
    .from("shops")
    .update({
      subscription_status: "active",
      subscription_plan: params.plan,
      paystack_subscription_code: params.paystackSubscriptionCode ?? null,
      paystack_customer_code: params.paystackCustomerCode ?? null,
      subscription_period_end: params.periodEnd ?? null,
      subscription_updated_at: new Date().toISOString(),
    })
    .eq("id", params.shopId);
  if (error) throw error;
}

export async function deactivateShopSubscription(
  admin: SupabaseClient,
  shopId: string,
  status: "cancelled" | "past_due" = "cancelled",
): Promise<void> {
  const { error } = await admin
    .from("shops")
    .update({
      subscription_status: status,
      subscription_updated_at: new Date().toISOString(),
    })
    .eq("id", shopId);
  if (error) throw error;
}

export function periodEndFromPlan(plan: SubscriptionPlan): string {
  const d = new Date();
  if (plan === "yearly") {
    d.setFullYear(d.getFullYear() + 1);
  } else {
    d.setMonth(d.getMonth() + 1);
  }
  return d.toISOString();
}
