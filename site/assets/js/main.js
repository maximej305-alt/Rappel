/* ============================================================
   Rappel+ — Site officiel · JS minimal (zéro dépendance)
   ============================================================ */

// ── Configuration éditable ────────────────────────────────────
const SITE_CONFIG = {
  // Lien du téléchargement APK.
  // Par défaut : fichier à la racine du dépôt GitHub.
  // Local : "./apk/Rappel+.apk" · Google Play plus tard : lien du store.
  apkUrl:
    "https://github.com/maximej305-alt/Rappel/raw/master/Rappel%2B.apk",
  version: "1.0.3",
  size: "61,8 Mo",
  minAndroid: "Android 7.0 (API 24) et plus",
};

// Injecte la config (texte et liens)
document.querySelectorAll("[data-config]").forEach((el) => {
  const key = el.dataset.config;
  if (SITE_CONFIG[key]) {
    if (el.tagName === "A") el.href = SITE_CONFIG[key];
    else el.textContent = SITE_CONFIG[key];
  }
});
document.querySelectorAll("a[data-apk-link]").forEach((a) => {
  a.href = SITE_CONFIG.apkUrl;
});

// ── Header compact au scroll ─────────────────────────────────
const header = document.getElementById("header");
let ticking = false;
function updateHeader() {
  header.classList.toggle("scrolled", window.scrollY > 24);
  ticking = false;
}
window.addEventListener(
  "scroll",
  () => {
    if (!ticking) {
      window.requestAnimationFrame(updateHeader);
      ticking = true;
    }
  },
  { passive: true }
);
updateHeader();

// ── Menu mobile ──────────────────────────────────────────────
const toggle = document.querySelector(".nav-toggle");
if (toggle) {
  toggle.addEventListener("click", () => {
    const open = header.classList.toggle("nav-open");
    toggle.setAttribute("aria-expanded", String(open));
    toggle.setAttribute("aria-label", open ? "Fermer le menu" : "Ouvrir le menu");
    toggle.textContent = open ? "✕" : "☰";
  });
  document.querySelectorAll(".nav-mobile a").forEach((a) =>
    a.addEventListener("click", () => {
      header.classList.remove("nav-open");
      toggle.setAttribute("aria-expanded", "false");
      toggle.textContent = "☰";
    })
  );
}

// ── Apparitions discrètes au scroll ──────────────────────────
const revealables = document.querySelectorAll(".reveal");
if ("IntersectionObserver" in window && revealables.length) {
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add("visible");
          io.unobserve(e.target);
        }
      });
    },
    { threshold: 0.1, rootMargin: "0px 0px -40px 0px" }
  );
  revealables.forEach((el) => io.observe(el));
} else {
  revealables.forEach((el) => el.classList.add("visible"));
}
