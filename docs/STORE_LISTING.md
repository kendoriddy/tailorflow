# Play Store / app listing copy

Keep listing text in this file so you can update store pages without searching the repo. Align with [`lib/core/brand.dart`](../lib/core/brand.dart) and [`website/site-config.js`](../website/site-config.js) for the **product** name; each tailor can white-label **inside** the app via Settings → Branding.

## Short description (80 chars max)

```
Customers, orders, payments & WhatsApp reminders for tailoring shops. Works offline.
```

## Full description

```
TailorFlow helps small tailoring shops run day-to-day work from one phone — even when the network is poor or offline.

• Customers & measurements — keep profiles and measurement sheets on device
• Orders & due dates — track status from booked to ready
• Payments — agreed price, partial payments, balance at a glance
• WhatsApp reminders — polite prefilled messages for “order ready” and payment reminders
• Promo campaigns — send discount offers to selected customers via WhatsApp
• Optional cloud backup — sync when you sign in with Supabase

Free plan limits (customer count and WhatsApp messages per month) are set by your service provider and can change over time. Upgrade for unlimited customers and messaging when subscriptions are enabled.

Built for Nigerian shop-floor tone: simple, fast, and readable in bright light.
```

## Subscription / in-app products

Paystack (see [`docs/PAYSTACK_SETUP.md`](PAYSTACK_SETUP.md)):

| Product | Price          | Entitlement                                              |
| ------- | -------------- | -------------------------------------------------------- |
| Monthly | ₦2,000 / month | Unlimited active customers + unlimited WhatsApp handoffs |
| Yearly  | ₦19,800 / year | Same as monthly                                          |

## Privacy policy URL

Use `Brand.privacyPolicyUrl` in code — currently hosted at your `siteUrl` + `/privacy.html`.
