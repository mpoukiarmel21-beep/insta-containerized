# Recherche : projets similaires existants

> Date : 2026-08-25 · Recherche OpenCode pour le projet INSTA
> Objectif : identifier les briques existantes, récentes et maintenues, avant de tout recoder de zéro.

---

## 1. Conteneurs / multi-comptes (équivalent Crane, mais sans jailbreak)

### LiveContainer — ⭐ LA référence actuelle

| | |
|---|---|
| Repo | https://github.com/LiveContainer/LiveContainer |
| Licence | Apache 2.0 |
| Jailbreak requis | **Non** |
| Statut 2026 | Activement maintenu (nightlies régulières) |

**Ce que ça fait :**
- Lance une app iOS **sans l'installer** (dlopen du binaire invité).
- **Plusieurs conteneurs isolés par app** : chaque conteneur a son propre `HOME`, ses préférences, ses documents.
- **128 groupes d'accès Keychain** alloués aléatoirement → semi-isolation des comptes/cookies/sessions.
- Intègre un **TweakLoader** : charge automatiquement les `.dylib` (tweaks) dans l'app invitée — global ou par app.
- Mode JIT-less : re-sign automatique avec le certificat de LiveContainer.
- Multitâche (fenêtres virtuelles) sur iPadOS.

**Limites documentées (important à connaître avant de coder) :**
- Les conteneurs invités ne sont **pas sandboxés entre eux** (une app peut lire les données d'une autre si elle essaie vraiment).
- Extensions d'app non supportées.
- Notifications push distantes non garanties.
- Une seule app invitée lancée à la fois.

### Crane (jailbreak uniquement)
Référence historique du concept. Nécessite un device jailbreaké → hors périmètre ici puisque la cible est iPhone 11/12 **non jailbreakés via Sideloadly**.

---

## 2. Faux GPS injectable dans une IPA sideloadée

### LSpoof — ⭐ Exactement le besoin exprimé

| | |
|---|---|
| Repo | https://github.com/ezzuldinSt/LSpoof |
| Créé | 2026-05-29 (très récent) |
| Jailbreak requis | **Non** |
| Build | Theos, SDK iPhoneOS 16, arm64, ARC |

**Ce que ça fait :**
- Dylib injectée via patch Mach-O `LC_LOAD_DYLIB` (insert_dylib).
- Swizzle de `CLLocationManager` :
  - `setDelegate:` → intercepte `locationManager:didUpdateLocations:` et la version legacy.
  - getter synchrone `.location`.
- UI de sélection : geste **3 doigts maintenus 0,8 s** → ouvre une carte avec recherche, favoris, récents, bouton « Apply ».
- Désactive le geste quand le picker est ouvert pour ne pas gêner MapKit de l'hôte.

**Ce qui n'est PAS hooké (limites honnêtes) :**
- Swift `CLLocationUpdate.liveUpdates()` (iOS 17+ async).
- Géoloc par WiFi/IP/téléphonie côté serveur.
- Détections anti-fraude serveur (Instagram/Meta fait ce genre de checks).

### Alternatives
- **Locsim** (udevsharold) — jailbreak requis, ligne de commande.
- **Relocate2** (julioverne) — jailbreak requis. Tu as déjà le `.deb`.
- **pymobiledevice3** (`developer dvt simulate-location`) — spoof GPS depuis un PC en mode développeur, iOS 17+. Fonctionne sur iOS 26 mais nécessite un tunnel USB + Developer Mode activé. Pas embarquable dans une IPA.

---

## 3. Spoofing modèle/matériel (« Ghost »)

### Ghost tweak (rootless)
Tu as déjà le `.deb`. Il hook principalement :
- `sysctl hw.model` / `hw.machine`
- `uname`
- IOKit `HardwareModel`
- Certaines clés `MGCopyAnswer`

### ⚠️ Retour terrain important (r/jailbreak, BlackHatWorld 2026)
> « If you're looking for this and using it for IG, it's practically useless; IG will still detect that you're using a real device instead of the one spoofed from Ghost. »

Instagram/Meta croise plusieurs signaux indépendants :
- Empreinte TLS/HTTP2 côté client (pas hookable simplement au niveau userland).
- Signaux serveur : IP/proxy vs cohérence géo-device.
- Comportemental : rythme de frappe, timing réseau, patterns d'usage.
- Attestation device quand disponible.

**Conséquence architecturale** : un simple hook userland du device model est insuffisant et surtout fragile face aux mises à jour Instagram. C'est la raison principale pour laquelle tes projets précédents « marchaient pas jusqu'au bout ».

### Nugget (leminlimez/Nugget)
Spoof device model via exploit SparseRestore, **sans jailbreak**, mais modifie des plists système globales → s'applique à TOUT le téléphone, pas par-conteneur. Ne colle pas au besoin « chaque container = un faux téléphone différent ».

---

## 4. Injection dylib + re-sign (la brique technique centrale)

| Outil | Rôle | Plateforme | Note |
|---|---|---|---|
| **TrollFools** (Lessica) | Injection in-place avec insert_dylib + ChOma | iOS | 3.6k★, très actif |
| **Azula** (Paisseon) | App d'injection multi-dylib | macOS/iOS | Simple |
| **iresign** (isigner) | Inject + re-sign en CLI | Win/Linux/macOS/iOS | Basé sur **zsign** |
| **insert_dylib** | Patch LC_LOAD_DYLIB | macOS | Brique bas niveau |
| **ldid** | Signature ad-hoc / entitlements | Cross | Utilisé partout |
| **Theos** | Build des tweaks (.dylib) depuis source | Cross | Standard jailbreak |
| **zsign** | Re-sign complet d'un .app | Cross | Le plus fiable en CLI headless |

---

## 5. Conclusion stratégique

Ne pas réinventer la roue. Deux voies possibles :

**Voie A — Composition (recommandée)**
1. Prendre **LiveContainer** comme moteur de conteneurs (il existe, open-source, maintenu).
2. Y injecter un **fork de LSpoof** adapté (UI map + intégration par-conteneur).
3. Éviter le hook device-model « naïf » type Ghost : c'est le point faible détectable.

**Voie B — Dylib unique custom**
1. Une seule dylib injectée dans l'IPA Instagram via `insert_dylib`.
2. Elle gère : UI bouton flottant, gestion conteneurs, hooks CLLocation, hooks device-info.
3. Beaucoup plus dur à faire correctement (persistance, isolation, stabilité) et c'est exactement là où tes projets précédents ont cassé (crash au lancement, compte qui disparaît, écran figé).

La Voie A est celle qui a le plus de chances de tenir dans le temps car LiveContainer résout déjà les problèmes difficiles (persistance, keychain, isolation partielle) qui font partie des bugs que tu as déjà rencontrés.
