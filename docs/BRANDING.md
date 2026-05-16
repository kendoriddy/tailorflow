# Branding — rename in two files

When you choose a new product name, update **both** places so the app and website stay in sync.

| Surface                                 | File                                                                                                   |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Flutter app (labels, feedback subjects) | [`lib/core/brand.dart`](../lib/core/brand.dart) → `Brand.appName`                                      |
| Marketing website                       | [`website/site-config.js`](../website/site-config.js) → `appName` (+ related copy)                     |
| Privacy policy URL (Play Store + app)   | [`lib/core/brand.dart`](../lib/core/brand.dart) → `privacyPolicyUrl`; host at `{siteUrl}/privacy.html` |
| Privacy contact email                   | `Brand.privacyContactEmail` and `site-config.js` → `privacyContactEmail`                               |

Package IDs (`tailorflow_ng`, `ng.tailorflow.*`) can stay as-is until you ship a new store listing.

After renaming, also update:

- `website/robots.txt` — only if you change domain (use relative `Sitemap: /sitemap.xml` when possible)
- `website/sitemap.xml` — set `<loc>` URLs to your `siteUrl` from `site-config.js`
- App icons / favicon (optional rebrand)

---

## APK from GitHub Releases

Use this for `apkUrl` in `site-config.js`.

### One-time setup

1. Push your repo to GitHub (e.g. `github.com/YOUR_USERNAME/tailorflow_ng`).
2. Build a release APK locally:

   ```bash
   cd tailorflow_ng
   flutter build apk --release \
     --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
   ```

3. The file is at: `build/app/outputs/flutter-apk/app-release.apk`

### Publish a release

1. On GitHub: **Repository → Releases → Create a new release**.
2. Choose a tag (e.g. `v1.0.0`) and publish.
3. Under **Assets**, drag and upload `app-release.apk`.
4. Keep the filename **`app-release.apk`** (matches the URL below).

### APK download URL

**Latest release (updates automatically when you publish a new release):**

```text
https://github.com/YOUR_USERNAME/tailorflow_ng/releases/latest/download/app-release.apk
```

Replace `YOUR_USERNAME` with your GitHub username or org.

**Pinned to one version:**

```text
https://github.com/YOUR_USERNAME/tailorflow_ng/releases/download/v1.0.0/app-release.apk
```

Paste the URL into `website/site-config.js` → `apkUrl`.

### Notes

- The repo must be **public**, or use a public release asset; private repos need another host (Supabase Storage, Cloudflare R2, etc.).
- `latest` always points at the newest release; the asset name must match exactly (`app-release.apk`).
- Test the link in a browser — it should start a download.

---

## Website domain

Set `siteUrl` in `site-config.js` (e.g. `https://tailorflow.kennyonifade.com`).

Hosting steps: [`website/DEPLOY.md`](../website/DEPLOY.md).
