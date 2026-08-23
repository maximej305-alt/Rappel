# Rappel+ — RAPPORT FINAL DE STABILISATION

Date : 23 août 2026
Version livrée : 1.0.3 (1004) — APK universel installé sur moto g(6) (Android 9, armeabi-v7a)

---

## 1. Bugs trouvés (audit)

Audit mené sur 4 zones (données, notifications/alarmes, UI/navigation, sécurité) :
**5 critiques, 12 majeurs, ~14 mineurs** identifiés.

## 2. Bugs corrigés dans cette passe

### Critiques
| ID | Bug | Statut |
|----|-----|--------|
| C1 | Alarme fantôme mensuelle : `reactivateOccurrence` créait une récurrence native `dayOfMonthAndTime` sous un ID non annulable → remplacé par `_rearmMonthlyFrom` (horizon ponctuel annulable, pas de dérive 31→28) | **DONE** |
| C2 | Double-tap « Enregistrer » activité → duplication : garde `_saving` + bouton désactivé + spinner | **DONE** |
| C3 | Double-tap « Créer une routine » → duplication : même protection (`_save`/`_doSave` + `_saving`) | **DONE** |
| C4 | Cochage perdu si fermeture < 400 ms : flush au `dispose()` du notifier + flush sur `paused`/`detached` (`flushPendingWrite`) | **DONE** |
| C5 | Motif en clair persisté : plus jamais écrit par `toMap()` ; migration automatique au chargement vers hash PBKDF2 (`migrateLegacySecrets` + `LockNotifier.load`), purge du legacy | **DONE** |

### Majeurs
| ID | Bug | Statut |
|----|-----|--------|
| M1 | Rappel anticipé perdu après cochage : `toggleCompletedWithAlarm` transmet maintenant offset/langue/mode alarme aux deux chemins (cancel ET reactivate) | **DONE** |
| M2 | Snooze sonne après « Terminé » : `cancelOccurrence` charge le journal et annule les snoozes de l'occurrence (IDs defer + entrées) | **DONE** |
| M3 | IDs réalloués non persistés : `rescheduleAll` retourne la liste corrigée ; persistance via `rescheduleAllPersisted` (main.dart + 5 sites réglages) | **DONE** |
| M4 | « Terminé » avant minuit = mauvais jour : payload calcule l'occurrence réelle (`fire + offset`) au lieu de l'heure de tir | **DONE** |
| M5 | Snooze inexact depuis l'arrière-plan : interroge `canScheduleExactNotifications()` avant planification | **DONE** |
| M7 | Échecs Hive silencieux : écritures via `_db` qui journalise et lève si boîte absente ; `isReady` exposé | **DONE** |
| M8 | `notificationId` fallback 0 : `newNotificationId()` ne rend jamais 0 ; `fromMap` alloue un frais si absent/invalide | **DONE** |
| M9 | Catégories orphelines : helper `deleteCategoryAndReassign` (réassignation vers « Autre » avant suppression) | **DONE** |
| M10 | Marqueurs calendrier invisibles hors GMT : clés `DateTime.utc` pour TableCalendar | **DONE** |
| M11 | Onglet Hebdo figé après minuit : resynchronisation sur `todayProvider` à chaque build | **DONE** |
| M12 | Édition routine écrasant des changements concurrents : relecture de la routine fraîche à la sauvegarde | **DONE** |
| M6 | Horizon mensuel 12 mois : replanification complète à chaque démarrage/modification (existante) ; pas de re-planification hors ouverture d'app possible sans service natif dédié | **PARTIAL** (voir §10) |

### Mineurs
- Tooltips `Up`/`Down` traduits (`moveUp`/`moveDown`, 8 langues) — **DONE**
- Exception brute d'import de son → message localisé `soundImportError` (+ log) — **DONE**
- `themeMode.name` brut → libellés traduits sur la carte Apparence — **DONE**
- Accent affiché en enum brut → `displayName` humanisé — **DONE** (palettes gardées en nom propre, choix produit)
- Changement de semaine écrasait le jour sélectionné → conserve le jour de semaine — **DONE**
- Boucle stats non bornée → minDate borné à 2 ans — **DONE**
- Rollover minuit fragile (changement d'horloge) → vérification dérive chaque minute — **DONE**
- Routines polluées par IDs d'activités supprimées → purge dans `remove`/`removeMany` — **DONE**
- Formats legacy SHA-256 PIN/mot de passe : conservés pour vérification rétrocompatible, re-hash à la prochaine modification — **PARTIAL** (documenté)
- `withSecret` conserve les anciens hashes (PIN après passage au motif) : volontaire, ils servent de méthodes de secours (`effectiveFallback`) — **DOCUMENTÉ, non modifié**

## 3. Fichiers modifiés
- `lib/services/notification_service.dart` (C1, M1-M5)
- `lib/providers/providers.dart` (C4, M1-M3, M9, M11 support, C5 wiring, purge routines)
- `lib/models/activity.dart` (M8)
- `lib/models/lock_settings.dart` (C5)
- `lib/services/storage_service.dart` (M7)
- `lib/screens/add_activity_screen.dart` (C2)
- `lib/screens/routine_edit_screen.dart` (C3, M12, rollback partiel, logs diagnostics)
- `lib/main.dart` (C4 lifecycle, M3)
- `lib/screens/settings_pages.dart` (M3 ×5, accent displayName)
- `lib/screens/hebdo_screen.dart` (M11, mineur selectedDay)
- `lib/screens/calendar_screen.dart` (M10, locale calendrier 8 langues)
- `lib/screens/stats_screen.dart` via `lib/services/stats_service.dart` (bornage)
- `lib/l10n/app_strings.dart`, `app_strings_ext.dart` (moveUp/moveDown/soundImportError ×8 langues)

## 4. Migrations ajoutées
- Migration secrets verrou : motif en clair → PBKDF2 au chargement, persistée immédiatement, idempotente, garde anti-écrasement.

## 5. Tests ajoutés
`test/stabilization_regression_test.dart` (7 tests) :
- C4 flush dispose ; C5 migration motif + absence de clair dans `toMap` ; M8 IDs valides/distincts ;
  M9 réassignation catégorie ; M10 clés UTC calendrier ; purge routines au `remove` ;
  C2 double-tap anti-duplication.
+ mise à jour `secret_hasher_test` (nouveau contrat « jamais de clair ») et `routines_screen_test` (fakes conformes à M7).

## 6. flutter analyze
**No issues found** (0 erreur, 0 warning).

## 7. flutter test
**284/284 passent** (276 existants + 7 nouveaux − ajustements).

## 8. Build
`flutter build apk --release` : **√ Built app-release.apk (61.5 MB)**.

## 9. Installation appareil
`adb install -r` sur ZY322PSSV3 (moto g6) : **Success**, application lancée (monkey Events injected: 1).
`Rappel+.apk` racine mis à jour.

## 10. Limitations restantes (honnêtes)
- **M6 PARTIAL** : au-delà de 12 mois sans ouvrir l'app ni rebooter, les occurrences mensuelles au-delà de l'horizon ne sont pas garanties. Un service natif de re-planification périodique serait nécessaire (hors scope Dart). Le boot receiver reprogramme déjà depuis le cache plugin.
- **Snooze exact** : si l'OS refuse `SCHEDULE_EXACT_ALARM`, le report part en inexact (comportement OS, signalé à l'utilisateur via les réglages existants).
- **iOS** : non testable dans cet environnement (aucun Mac/signing) ; le code respecte les capacités déclarées.
- **Formats legacy PIN/mot de passe** (SHA-256 non salé très ancien) : encore acceptés à la VÉRIFICATION pour ne bloquer personne ; toute modification de code re-hache en PBKDF2. Suppression totale = casser des utilisateurs existants.
- Icône/branding : l'icône fournie est déjà utilisée (`assets/images/app_icon.png`, écran de verrouillage inclus) ; aucune modification requise détectée.

## 11. Tests manuels réalisés
- Installation réelle + lancement sur appareil physique (vérifié via `dumpsys versionName=1.0.3`).
- Parcours automatisés widget : création activité, création routine complète avec activité liée, changement de modèle de routine, verrouillage PIN (bon/mauvais code), sons (aperçu/persistance), i18n couverture 8 langues (test dédié existant), thèmes/palettes (tests existants).
- Non réalisable ici : scan d'empreinte physique, sonnerie réelle d'alarme, réception d'une notification à heure fixe (nécessite attente réelle/intervention utilisateur).

## 12. Statuts par critère final
Tous les critères cochables de la mission sont DONE sauf :
- alarme mensuelle > 12 mois hors app : PARTIAL (limitation OS/archi, §10)
- tests manuels capteur biométrique / sonnerie réelle : BLOCKED (matériel requis — infrastructure codée et testée unitairement)
