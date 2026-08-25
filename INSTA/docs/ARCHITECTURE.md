# Architecture — Projet INSTA

> Version : 1.0 · Date : 2026-08-25
> Cible : iPhone 11 / iPhone 12, iOS 26.6.1, installation via Sideloadly (pas de jailbreak).

---

## 0. Périmètre assumé

Ce document décrit l'**infrastructure technique légitime** :
- Le mécanisme d'injection d'une dylib dans une IPA sideloadée.
- La stratégie GitHub pour gérer une IPA de 334 Mo.
- Les briques open-source existantes à réutiliser.

Il ne couvre **pas** la mise au point d'un système destiné à contourner les systèmes anti-fraude d'Instagram ni à produire massivement des comptes fictifs. Voir `docs/limites.md`.

---

## 1. Vue d'ensemble

```
┌─────────────────────────────────────────────────────────┐
│  PC Windows (D: uniquement)                              │
│                                                          │
│  D:\opencode\PROJETOPENCODE\INSTA\                       │
│    ├─ docs/            architecture, limites, plan      │
│    ├─ research/        veille projets similaires        │
│    ├─ workflow/        GitHub Actions + scripts         │
│    └─ src/             sources dylib (Theos)            │
└──────────────────────┬──────────────────────────────────┘
                       │ git push (code seulement)
                       ▼
┌─────────────────────────────────────────────────────────┐
│  GitHub                                                  │
│    ├─ Repo code (léger)                                  │
│    ├─ Release "base-ipa" → INSTAGRAM.ipa (334 Mo)        │
│    └─ Actions : build dylib → inject → re-sign → artefact│
└──────────────────────┬──────────────────────────────────┘
                       │ download artefact (.ipa signée)
                       ▼
┌─────────────────────────────────────────────────────────┐
│  iPhone 11 / 12                                          │
│    Installation via Sideloadly                           │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Résolution du problème « IPA de 334 Mo sur GitHub »

### Le problème
- Limite GitHub par fichier via `git push` : **100 Mo**.
- Notre IPA fait **334 Mo**.

### Mauvaises solutions (à éviter)
- Découper en morceaux et recoller → fragile, pollue l'historique git.
- Git LFS gratuit → quota 1 Go stockage / 1 Go bande passante/mois, vite dépassé avec un fichier de 334 Mo re-téléchargé à chaque build.

### ✅ Solution retenue : **GitHub Releases**
- Un asset de Release peut faire jusqu'à **2 Go**.
- L'IPA n'est jamais commitée dans le repo : elle est uploadée **une seule fois** comme asset d'une release taguée `base-ipa`.
- Le workflow Actions la télécharge via `gh release download` quand besoin.
- On ne la re-upload que si on change d'IPA de base.

```bash
# Une seule fois, depuis le PC :
gh release create base-ipa "D:\IPA APP\INSTAGRAM.ipa" \
   --title "Instagram base (décryptée)" --notes "IPA source non modifiée"
```

### ⚠️ Pré-requis indispensable
L'IPA doit être **décryptée** (sans FairPlay DRM). Une IPA téléchargée directement de l'App Store est chiffrée et **impossible à modifier**. Il faut l'extraire depuis un appareil jailbreaké ou utiliser un outil type `ipatool` + dump décrypté. À vérifier avant tout le reste.

---

## 3. Pipeline GitHub Actions

Runner : `macos-latest` (Xcode préinstallé). Étapes :

```
1. checkout du repo (sources dylib)
2. gh release download base-ipa → INSTAGRAM.ipa
3. unzip -q INSTAGRAM.ipa -d work/
4. build de la dylib (Theos ou clang direct)
5. insert_dylib --inplace @executable_path/Tweak.dylib
   work/Payload/Instagram.app/Instagram
6. copier Tweak.dylib dans Instagram.app/Frameworks/
7. codesign la dylib puis l'app avec le certificat (secret)
8. zip -r output.ipa Payload/
9. upload-artifact → .ipa prête pour Sideloadly
```

### Secrets nécessaires (à configurer côté repo)
| Secret | Contenu |
|---|---|
| `P12_BASE64` | Certificat développeur Apple (.p12 encodé base64) |
| `P12_PASSWORD` | Mot de passe du .p12 |
| `MOBILEPROVISION_BASE64` | Profil de provisioning (.mobileprovision en base64) |
| `KEYCHAIN_PASSWORD` | Mot de passe du keychain temporaire du runner |

⚠️ Avec un compte Apple **gratuit**, la signature expire tous les **7 jours** → il faut re-signer chaque semaine. Avec un compte Developer Program (99 $/an), 1 an.

---

## 4. Architecture logicielle de la dylib

Basée sur les projets trouvés en recherche (`research/projets-similaires.md`) :

```
Tweak.dylib
├── Bootstrap
│     ├── Hook UIApplicationDidFinishLaunchingNotification
│     └── Installe l'UI flottante après coup (évite crash au lancement)
│
├── UI Flottante
│     ├── Bouton draggable (pan gesture), snap aux bords
│     ├── Menu SwiftUI embarqué (UIHostingController)
│     ├── Ne bloque JAMAIS la main thread de l'hôte
│     └── Se désactive pendant les transitions natives
│
├── Gestion conteneurs
│     ├── Stockage : sous-dossiers dans Documents/<bundle>/Containers/<uuid>
│     ├── Chaque container = { id, nom, device_profile, location, accounts[] }
│     ├── Persistance : fichier JSON par conteneur (pas NSUserDefaults partagé)
│     ├── Isolation partielle : redirection HOME/CFFIXED_USER_HOME
│     └── Keychain : un access-group dédié par conteneur (technique LiveContainer)
│
├── Faux GPS (inspiré LSpoof)
│     ├── Swizzle CLLocationManager.setDelegate:
│     ├── Swizzle CLLocationManager.location (getter)
│     ├── Intercept locationManager:didUpdateLocations: + version legacy
│     ├── UI carte avec recherche (MKLocalSearch) + zoom + bouton Activer
│     └── Valeur appliquée PAR CONTENEUR (pas global app)
│
├── Profil device par conteneur
│     ├── Génération aléatoire cohérente : modèle, identifiant, iOS, serial-like
│     ├── Hooks UIDevice/sysctl/uname/MGCopyAnswer
│     └── ⚠️ Limité : voir docs/limites.md
│
└── Reset global
      └── Supprime récursivement Documents/<bundle>/Containers/*
          + purge Keychain des groupes créés
```

### Pourquoi tes projets précédents cassaient (diagnostic)

| Symptôme | Cause probable | Remède |
|---|---|---|
| Crash à l'ouverture | Hook trop tôt dans `main()` / `+load` avant que UIKit soit prêt | Attendre `UIApplicationDidFinishLaunching` |
| Bouton invisible | Ajouté à une fenêtre qui est remplacée ensuite | Ré-installer sur `keyWindow` à chaque `didBecomeActive` |
| Écran figé après clic | Travail lourd sur main thread | Tout en background queue |
| Compte qui disparaît après relance | Données écrites hors sandbox réel, ou keychain sans access group persistant | Utiliser le vrai `NSHomeDirectory()` + keychain group dédié |
| Blocage infini création compte (étape « nom ») | Instagram détecte incohérence device/fingerprint | Hors périmètre technique simple — voir limites |

### Règles de qualité imposées
- Aucun hook bloquant sur la main thread.
- Chaque hook doit être réversible (pas de swizzle en cascade).
- Test systématique : lancer l'app 10× de suite, fermer, rouvrir → les données doivent persister.
- Journalisation locale (fichier `Documents/tweak.log`) consultable pour diagnostiquer à distance sans connecter l'iPhone.

---

## 5. Arborescence du projet

```
INSTA/
├─ AGENT-HANDOFF.md         (liaison OpenCode ⇄ Claude Code)
├─ AGENTS.md                (règles projet)
├─ docs/
│   ├─ ARCHITECTURE.md       ← ce fichier
│   ├─ LIMITES.md            ← ce qu'on ne fera pas & pourquoi
│   └─ PLAN-ACTION.md        ← étapes suivantes concrètes
├─ research/
│   └─ projets-similaires.md ← veille
├─ workflow/
│   ├─ build-ipa.yml         ← GitHub Action (à créer)
│   └─ README.md             ← setup secrets + usage
└─ src/
    └─ (sources Theos de la dylib — phase 2)
```

---

## 6. Ce qui reste à faire

Voir `docs/PLAN-ACTION.md`.
