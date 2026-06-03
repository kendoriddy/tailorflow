import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

/// Paystack redirects here after checkout. Shows a simple page; the app detects
/// the URL in WebView and calls paystack-verify.
serve((req) => {
  const url = new URL(req.url);
  const reference =
    url.searchParams.get("reference") ?? url.searchParams.get("trxref") ?? "";

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Payment complete</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 28rem; margin: 3rem auto; padding: 0 1rem; text-align: center; }
    h1 { font-size: 1.25rem; }
  </style>
</head>
<body>
  <h1>Payment received</h1>
  <p>You can close this window and return to TailorFlow.</p>
  ${reference ? `<p style="color:#666;font-size:0.875rem">Ref: ${reference}</p>` : ""}
</body>
</html>`;

  return new Response(html, {
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
});
