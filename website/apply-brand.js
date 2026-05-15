(function () {
  const cfg = window.SITE_CONFIG;
  if (!cfg) return;

  const name = cfg.appName || "TailorFlow";
  const siteUrl = (cfg.siteUrl || "").replace(/\/$/, "");
  const tagline = cfg.tagline || "";
  const pageTitle = `${name} — ${cfg.pageTitleSuffix || "Tailoring shop app"}`;
  const metaDescription = `${name} is an offline-first mobile app for tailoring shops: ${tagline}`;

  function fill(template) {
    return (template || "").replace(/\{appName\}/g, name);
  }

  function setMeta(attr, key, value) {
    let el = document.querySelector(`meta[${attr}="${key}"]`);
    if (!el) {
      el = document.createElement("meta");
      el.setAttribute(attr, key);
      document.head.appendChild(el);
    }
    el.setAttribute("content", value);
  }

  /** Head-only updates — safe while <body> is still parsing. */
  function applyHead() {
    document.title = pageTitle;
    setMeta("name", "description", metaDescription);
    setMeta("property", "og:title", `${name} — Tailoring shop management`);
    setMeta("property", "og:description", tagline);
    setMeta("property", "og:site_name", name);
    setMeta("name", "twitter:title", name);
    setMeta("name", "twitter:description", tagline);

    if (siteUrl) {
      let canonical = document.querySelector('link[rel="canonical"]');
      if (!canonical) {
        canonical = document.createElement("link");
        canonical.rel = "canonical";
        document.head.appendChild(canonical);
      }
      const path = window.location.pathname.replace(/\/$/, "") || "/";
      canonical.href = siteUrl + (path === "/" ? "/" : path);

      setMeta("property", "og:url", siteUrl + path);
    }

    const ld = document.querySelector('script[type="application/ld+json"]');
    if (ld) {
      try {
        const data = JSON.parse(ld.textContent);
        data.name = name;
        data.description = tagline;
        ld.textContent = JSON.stringify(data);
      } catch (_) {
        /* ignore */
      }
    }
  }

  /** Needs the full DOM (hero buttons, footer, etc.). */
  function applyBody() {
    document.querySelectorAll("[data-brand='appName']").forEach((el) => {
      el.textContent = name;
    });

    document.querySelectorAll("[data-brand-template]").forEach((el) => {
      const key = el.getAttribute("data-brand-template");
      if (cfg[key]) el.textContent = fill(cfg[key]);
    });

    document.querySelectorAll("[data-brand-alt]").forEach((el) => {
      const kind = el.getAttribute("data-brand-alt") || "screenshot";
      el.alt = fill(
        el.getAttribute("data-brand-alt-template") || `${kind} in {appName}`,
      );
    });

    const phone = (cfg.whatsappPhone || "").replace(/\D/g, "");
    const waText = encodeURIComponent(fill(cfg.whatsappMessage || "Hi"));
    const whatsappUrl = phone
      ? `https://wa.me/${phone}?text=${waText}`
      : cfg.whatsappUrl || "#";

    const apk = cfg.apkUrl || "#";
    document.querySelectorAll("[data-apk-link], #apk-link").forEach((el) => {
      el.href = apk;
    });
    document
      .querySelectorAll("[data-whatsapp-link], #whatsapp-link")
      .forEach((el) => {
        el.href = whatsappUrl;
      });
  }

  applyHead();

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", applyBody);
  } else {
    applyBody();
  }
})();
