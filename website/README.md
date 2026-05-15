# Marketing website

Static landing page. Product name, domain, APK, and WhatsApp are configured in **`site-config.js`** only.

## Rename the product

1. `website/site-config.js` → `appName` (and copy fields if needed)
2. `lib/core/brand.dart` → `Brand.appName`

Details: [`docs/BRANDING.md`](../docs/BRANDING.md)

## Deploy to `tailorflow.kennyonifade.com`

Step-by-step: **[DEPLOY.md](DEPLOY.md)**

## Local preview

```bash
cd website
python3 -m http.server 8080
```

Open http://localhost:8080

## APK download URL

See **APK from GitHub Releases** in [`docs/BRANDING.md`](../docs/BRANDING.md), then set `apkUrl` in `site-config.js`.
