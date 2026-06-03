export const MONTHLY_AMOUNT_KOBO = 200_000;
export const YEARLY_AMOUNT_KOBO = 1_980_000;

export type SubscriptionPlan = "monthly" | "yearly";

export function planAmountKobo(plan: SubscriptionPlan): number {
  return plan === "monthly" ? MONTHLY_AMOUNT_KOBO : YEARLY_AMOUNT_KOBO;
}

export function planPaystackCode(
  plan: SubscriptionPlan,
  monthlyCode: string,
  yearlyCode: string,
): string {
  return plan === "monthly" ? monthlyCode : yearlyCode;
}

export async function paystackRequest<T>(
  secretKey: string,
  path: string,
  init?: RequestInit,
): Promise<T> {
  const res = await fetch(`https://api.paystack.co${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
  const body = await res.json();
  if (!res.ok || body?.status === false) {
    const msg = body?.message ?? `Paystack HTTP ${res.status}`;
    throw new Error(msg);
  }
  return body as T;
}

export async function verifyPaystackSignature(
  secretKey: string,
  rawBody: string,
  signature: string | null,
): Promise<boolean> {
  if (!signature) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secretKey),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(rawBody),
  );
  const digest = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return digest === signature;
}
