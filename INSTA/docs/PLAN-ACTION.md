# Plan d'action

> Prochaine étape concrète pour le prochain agent (OpenCode ou Claude Code).

---

## Phase 0 — Infrastructure (ce dépôt)
- [x] Recherche projets similaires (`research/projets-similaires.md`)
- [x] Architecture (`docs/ARCHITECTURE.md`)
- [x] Limites (`docs/LIMITES.md`)
- [x] **GitHub Actions workflow** : `workflow/build-ipa.yml` (inject + sign)
- [x] **workflow/README.md** : setup des secrets (P12, provisioning, keychain)
- [ ] **Repo GitHub distant** : créer le repo, uploader l'IPA en Release `base-ipa` ← À FAIRE par l'utilisateur (besoin de l'IPA décryptée + compte)

## Phase 1 — Sources de la dylib
- [x] `src/Tweak.m` — point d'entrée + hooks (après launch)
- [x] `src/FloatingButton.m` — UI draggable + menu conteneurs
- [x] `src/ContainerManager.m` — CRUD conteneurs + persistance JSON
- [x] `src/LocationSpoofer.m` — hook CLLocationManager + carte/recherche
- [x] `src/DeviceProfile.m` — génération profil cohérent + hooks UIDevice/uname
- [x] `src/TweakLogger.m` — journal local pour diagnostic à distance
- [x] `src/Makefile` + `src/control`
- [x] `src/entitlements.xml`
- [x] `src/README.md`
> Note : écrit en Objective-C (`.m`), compilé par `clang` sur le runner (pas de Theos requis).

## Phase 2 — Build réel (GitHub)
- [ ] Créer repo GitHub, pousser ce code
- [ ] Uploader `INSTAGRAM.ipa` décryptée en Release `base-ipa`
- [ ] Configurer les 4 secrets (P12, MOBILEPROVISION, etc.)
- [ ] Lancer le workflow → récupérer `Instagram-Containerized.ipa`
- [ ] Installer via Sideloadly sur iPhone 11/12

## Phase 3 — Tests terrain (à faire par l'utilisateur)
- [ ] Crash au lancement ? → voir tweak.log
- [ ] Bouton flottant visible + déplaçable ?
- [ ] Création conteneur + persistance après relance (10×) ?
- [ ] Faux GPS appliqué + reçu par Instagram ?
- [ ] Reset global purge tout ?

## Points de vigilance (bugs récurrents à chaque étape)
- Hook uniquement après `UIApplicationDidFinishLaunching`.
- Jamais de travail lourd sur main thread.
- Ré-installer l'UI flottante sur `keyWindow` à chaque `didBecomeActive`.
- Keychain : utiliser un access group persistant par conteneur.
- Logger tout dans `Documents/tweak.log`.
