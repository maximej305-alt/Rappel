# Site officiel de Rappel+

Site vitrine statique (HTML/CSS/JS pur — zéro dépendance, zéro build).

## Lancer le site en local

Option 1 — double-cliquer sur `index.html` (fonctionne tel quel).

Option 2 — petit serveur local (recommandé) :

```bash
cd site
python -m http.server 8080
# puis ouvrir http://localhost:8080
```

## Structure

```
site/
├── index.html              ← page principale (hero, fonctionnalités, galerie…)
├── confidentialite.html    ← politique de confidentialité
├── conditions.html         ← conditions d'utilisation
├── a-propos.html           ← à propos
├── support.html            ← FAQ + contact
└── assets/
    ├── css/style.css       ← design system (couleurs de l'app)
    ├── js/main.js          ← menu mobile + config éditable
    ├── img/logo.png        ← logo officiel (copié depuis l'app)
    └── screens/*.png       ← captures réelles de l'application
```

## Remplacer les captures d'écran

Remplacez simplement les fichiers dans `assets/screens/` en gardant les mêmes
noms : `home.png`, `add-activity.png`, `routines.png`, `stats.png`,
`calendar.png`, `appearance.png`, `security.png`, `languages.png`.

Format conseillé : PNG largeur 540 px (bon compromis qualité/poids).

## Mettre à jour l'APK / le lien de téléchargement

Ouvrez `assets/js/main.js` et modifiez le bloc `SITE_CONFIG` :

```js
const SITE_CONFIG = {
  apkUrl: "https://github.com/maximej305-alt/Rappel/raw/master/Rappel%2B.apk",
  version: "1.0.3",
  size: "61,8 Mo",
  minAndroid: "Android 7.0 (API 24)",
};
```

- Lien actuel : l'APK stocké à la racine du dépôt GitHub.
- Pour héberger l'APK dans le site : créez `site/apk/`, copiez-y le fichier,
  et mettez `apkUrl: "./apk/Rappel+.apk"`.
- Pour Google Play plus tard : remplacez par le lien du store.

## Mettre à jour la version affichée

Même bloc `SITE_CONFIG` (champ `version`). Pensez à mettre à jour aussi la
balise `<title>`/meta si besoin.

## Déploiement gratuit

### GitHub Pages (recommandé)

1. Pousser le dossier `site/` sur le dépôt GitHub.
2. GitHub → **Settings → Pages**.
3. Source : branche `master`, dossier **`/site`** (ou `/docs` si renommé).
4. Le site est en ligne sur `https://maximej305-alt.github.io/Rappel/`.

### Alternatives

- **Netlify / Vercel** : glisser-déposer le dossier `site/` — aucun réglage.
- **Cloudflare Pages** : idem, gratuit et rapide.

## Notes

- Aucune donnée personnelle n'est collectée par le site (pas de formulaire
  actif, pas d'analytics).
- Les blocs « 📌 À compléter » dans les pages légales sont à remplir avant
  une publication commerciale.

> D�ploy� automatiquement via GitHub Actions � chaque mise � jour du dossier site/.
