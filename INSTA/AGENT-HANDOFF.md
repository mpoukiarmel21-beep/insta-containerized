# AGENT-HANDOFF — Projet INSTA (IGContainerMod)

## État actuel
Projet démarré de zéro par ox-alpha (opencode). Objectif : tweak dylib injecté dans une IPA Instagram
**décryptée** (vérifié : `cryptid=0`, arm64 non-fat) pour ajouter :
conteneurs isolés façon Crane (comptes persistants par conteneur), spoof d'appareil unique par conteneur,
fake localisation avec carte (recherche ville / zoom / activer), bouton flottant draggable,
« Tout réinitialiser », et crash-reporter automatique en Issues GitHub.
Compilation du dylib sur GitHub Actions (macOS runner) — impossible sur ce PC Windows.
L'IPA de base (334 Mo) ne vit PAS dans git : elle est fournie comme **Release asset** du repo.

Décisions validées par l'utilisateur :
- Signature : **GitHub signe avec son certificat** (secrets P12 + provisioning requis).
- Diagnostic : **Issues GitHub auto** à chaque crash.
- IPA de base : **Release asset** du repo.
- Proxy par conteneur : **reporté** à une 2e passe.

## En cours
- Agent : **ox-alpha (opencode)** — depuis 2026-08-25, session active.
- Périmètre verrouillé : `IGContainerMod/` uniquement (code tweak + workflow + scripts).

## Prochaine étape
1. Terminer l'écriture des sources sous `IGContainerMod/tweak/` (ordre : core isolation → spoofs → UI → logger → Tweak.x).
2. Écrire `.github/workflows/build.yml` + `scripts/`.
3. Créer le repo GitHub privé, y pousser, uploader `INSTAGRAM.ipa` (source : `D:\IPA APP\INSTAGRAM.ipa`)
   comme asset d'une release taguée `base-ipa`.
4. Configurer les secrets : `P12_BASE64`, `P12_PASSWORD`, `MOBILEPROVISION_BASE64`, `CERT_IDENTITY`,
   `GH_ISSUE_TOKEN` (PAT création d'issues), `GH_ISSUE_REPO` (`owner/repo`).
   ⚠️ Le provisioning profile DOIT autoriser le bundle id `com.burbn.instagram`.
5. Lancer le workflow (`workflow_dispatch`), récupérer l'IPA signée en draft release, installer via Sideloadly.

## Blocages / risques
- Aucune compilation/test iOS possible localement (Windows) → validation par relecture + crash-reporter distant.
- Détection Meta possible malgré l'isolation → recommandation : proxies + 1 compte/conteneur + délais réalistes.
- Extensions (appex) tournent dans des processus séparés sans notre dylib → input workflow
  `strip_extensions` recommandé pour usage multi-comptes intensif.
- NSUserDefaults reste partagé entre conteneurs en v1 (sessions/comptes eux sont bien isolés via
  Keychain + redirection home). Limitation documentée dans README.
- Certificat gratuit = expiration 7 jours ; l'utilisateur utilise son propre cert (choix acté).

## Journal

### 2026-08-25 — ox-alpha (opencode)
- Prise de main du projet INSTA. Analyse du fichier source : `INSTAGRAM.ipa` = binaire arm64
  **décrypté** (`LC_ENCRYPTION_INFO_64 cryptid=0`, non-fat) → injection directe possible, pas besoin
  de décryptage jailbreak. Taille 334 Mo → stratégie Release asset (limite Git 100 Mo/fichier).
- Architecture complète définie et validée par l'utilisateur (voir `IGContainerMod/README.md`) :
  redirection home par conteneur (`<home>/.igcm/<uuid>/data/`), namespacing Keychain par conteneur,
  spoof device unique (IDFV/modèle/iOS) par conteneur, fake location via CLLocationManager,
  UI flottante sur UIWindow dédiée transparente (non bloquante pour Instagram),
  SideloadFix (portage opa334/IGSideloadFix) contre le bug « bloqué écran nom / crash login »,
  crash-reporter → Issues GitHub.
- Pipeline build retenu (pattern éprouvé Apollo-Reborn) : macOS runner + theos-action +
  cyan (pyzule-rw) pour l'injection + codesign avec cert utilisateur.
- Début implémentation : arborescence créée sous `IGContainerMod/`.
