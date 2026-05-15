/**
 * Single place to change product name, domain, and download links for the website.
 *
 * When you pick a new name, also update lib/core/brand.dart (Flutter app) to match.
 * See docs/BRANDING.md in the repo root.
 */
window.SITE_CONFIG = {
  // —— Brand (change these when you rename) ——
  appName: "TailorFlow",
  tagline:
    "Offline-first app for tailoring shops — customers, orders, payments, and WhatsApp reminders.",
  pageTitleSuffix: "Customers, orders & payments for tailoring shops",

  // Public URL where this site is hosted (no trailing slash).
  siteUrl: "https://tailorflow.kennyonifade.com",

  // Copy with {appName} replaced automatically on the page.
  heroLead:
    "{appName} helps you track customers, measurements, orders, and payments. Send polite WhatsApp reminders when dresses are ready or balances are due.",
  screenshotsHeading: "See {appName} in action",
  ctaHeading: "Ready to try {appName}?",
  privacyLead:
    "{appName} stores customer and order data on your device first. Optional cloud backup uses Supabase when you sign in and configure sync.",

  // —— Download & contact ——
  // GitHub Release APK: see docs/BRANDING.md § "APK from GitHub Releases"
  apkUrl:
    "https://github.com/kendoriddy/glory-transit/releases/download/tailorflow/tailorFlow_v0.1.apk",

  whatsappPhone: "2348060119837",
  whatsappMessage: "Hi, I'm interested in {appName}",
};
