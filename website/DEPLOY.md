# Deploy `tailorflow.kennyonifade.com`

Host the contents of the **`website/`** folder (not the whole Flutter repo) at:

`https://tailorflow.kennyonifade.com`

Before deploying, set `siteUrl`, `apkUrl`, and WhatsApp in [`site-config.js`](site-config.js).

---

## Option A — Vercel (recommended if `kennyonifade.com` is on Vercel)

### 1. Put the site on GitHub

If the repo is not on GitHub yet:

```bash
cd tailorflow_ng
git add website
git commit -m "Add marketing website"
git push
```

### 2. Create a Vercel project

1. Log in at [vercel.com](https://vercel.com) → **Add New → Project**.
2. **Import** your `tailorflow_ng` (or TailorFlow) Git repository.
3. Configure the project:
   - **Root Directory:** press **Edit** → set to **`website`** (Deploy only the marketing folder).
   - **Framework Preset:** **Other**.
   - **Build Command:** leave **empty** (static HTML).
   - **Output Directory:** **`.`** (dot — same folder as Root, since `website/` already contains `index.html`).
4. **Deploy**.

You get a preview URL like `https://tailorflow-ng-xxx.vercel.app` (name varies).

### 3. Add the custom subdomain

1. In the project: **Settings → Domains**.
2. Enter **`tailorflow.kennyonifade.com`** → **Add**.
3. Vercel shows **DNS instructions** (follow the exact record it displays).

Typical cases:

| Where DNS lives                              | What you usually add                                                                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **Vercel** (same team as `kennyonifade.com`) | Vercel can add the subdomain for you, or you add a **CNAME** in the apex project’s DNS as instructed.                                 |
| **Another registrar**                        | **CNAME** from `tailorflow` to the target Vercel shows (often something like `cname.vercel-dns.com` or your `*.vercel.app` hostname). |

Wait until the domain shows **Valid** in Vercel, then open `https://tailorflow.kennyonifade.com`.

### 4. HTTPS

Vercel provisions HTTPS automatically once the domain validates.

### 5. Update config

In `site-config.js`:

```js
siteUrl: "https://tailorflow.kennyonifade.com",
```

Align `sitemap.xml` `<loc>` entries with that host, commit, and push — Vercel redeploys on push.

---

## Option B — Cloudflare Pages

Use this if you prefer Cloudflare or the repo is not tied to Vercel.

### 1. Put the site on GitHub

Same as Option A step 1.

### 2. Create a Cloudflare Pages project

1. Log in at [dash.cloudflare.com](https://dash.cloudflare.com).
2. **Workers & Pages → Create → Pages → Connect to Git**.
3. Select the repository.
4. Build settings:
   - **Framework preset:** None
   - **Build command:** (leave empty)
   - **Build output directory:** `website`
5. **Save and Deploy**.

You get a URL like `https://tailorflow-ng.pages.dev`.

### 3. Add the custom subdomain

1. In the Pages project: **Custom domains → Set up a custom domain**.
2. Enter: `tailorflow.kennyonifade.com`.
3. Add the **CNAME** Cloudflare shows (e.g. `tailorflow` → your `*.pages.dev` host).

### 4. Update config

Same as Option A step 5 (`siteUrl`, `sitemap.xml`).

---

## Option C — Netlify

1. [app.netlify.com](https://app.netlify.com) → **Add new site → Import from Git**.
2. Repo: `tailorflow_ng`, **Base directory:** `website`, **Build command:** empty, **Publish directory:** `.` (or set base to `website` and publish `.`).
3. **Domain settings → Add custom domain:** `tailorflow.kennyonifade.com`.
4. Netlify shows a CNAME target (e.g. `something.netlify.app`).
5. At your DNS host for `kennyonifade.com`, add:

   | Type  | Name         | Value              |
   | ----- | ------------ | ------------------ |
   | CNAME | `tailorflow` | (Netlify’s target) |

6. Enable HTTPS in Netlify when DNS is verified.

---

## Option D — GitHub Pages (project or root)

1. Repo **Settings → Pages**.
2. **Source:** Deploy from branch; folder **`/website`** (or use a `gh-pages` branch containing only `website/` files).
3. **Custom domain:** `tailorflow.kennyonifade.com`.
4. DNS at your registrar:

   | Type  | Name         | Value                     |
   | ----- | ------------ | ------------------------- |
   | CNAME | `tailorflow` | `YOUR_USERNAME.github.io` |

5. Wait for GitHub’s certificate check to pass.

---

## Option E — cPanel / shared hosting (subdomain folder)

1. cPanel → **Subdomains** → create `tailorflow.kennyonifade.com` (document root e.g. `public_html/tailorflow`).
2. Upload everything inside `website/` into that folder (FTP or File Manager).
3. Ensure `index.html` is in the subdomain root.
4. Force HTTPS in cPanel if available.

---

## After go-live checklist

- [ ] `site-config.js`: `siteUrl`, `appName`, `apkUrl`, `whatsappPhone`
- [ ] `sitemap.xml`: `<loc>` URLs use `https://tailorflow.kennyonifade.com`
- [ ] `robots.txt`: `Sitemap: /sitemap.xml` (works on any host)
- [ ] Add screenshots under `website/assets/`
- [ ] Test APK button downloads the file
- [ ] Test WhatsApp opens with your number
- [ ] Submit sitemap in [Google Search Console](https://search.google.com/search-console) for the subdomain

---

## Future: move to a new domain

1. Change `siteUrl` in `site-config.js`.
2. Update `sitemap.xml` hosts.
3. Add the new domain in your host (Vercel/Netlify/Pages) and update DNS.
4. Keep the old subdomain redirecting for a while (optional).
