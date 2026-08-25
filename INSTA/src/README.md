# Containerizer — dylib Instagram (tweak personnel)

Dylib injectée dans une IPA Instagram sideloadée. Fournit :

- **Bouton flottant** draggable (⚙︎) → menu conteneurs.
- **Conteneurs isolés** : chaque conteneur = dossier `Documents/Containers/<uuid>`
  avec profil device + localisation + sessions de comptes (JSON persisté).
- **Faux GPS par conteneur** : swizzle `CLLocationManager` + carte (recherche, zoom, Activer).
- **Profil device par conteneur** : swizzle `UIDevice` + interpose `uname()`
  (modèle, iOS, serial générés aléatoirement et cohérents).
- **Reset global** : purge tous les conteneurs + données.
- **Journal local** `Documents/tweak.log` pour diagnostic à distance.

## Fichiers

| Fichier | Rôle |
|---|---|
| `Tweak.m` | Entrée ; installe les hooks après le lancement UIKit |
| `ContainerManager.{h,m}` | CRUD conteneurs, persistance JSON, reset |
| `DeviceProfile.{h,m}` | Spoof UIDevice + `uname()` (DYLD_INTERPOSE) |
| `LocationSpoofer.{h,m}` | Swizzle CLLocationManager + UI carte |
| `FloatingButton.{h,m}` | Bouton draggable + menu |
| `TweakLogger.{h,m}` | Journal fichier local |
| `Makefile` / `control` | Build Theos (local) |
| `entitlements.xml` | Droits (keychain groups par conteneur) |

## Règles de non-régression (bugs évités)

- Hooks installés **uniquement après** `UIApplicationDidFinishLaunchingNotification`.
- Jamais de travail lourd sur la main thread.
- Bouton ré-accroché à `keyWindow` à chaque `didBecomeActive`.
- Données écrites dans le **vrai `NSHomeDirectory()`** (persistent après relance).

## Build

- **CI (GitHub Actions)** : `clang` compile `src/*.m` directement (voir `../workflow/build-ipa.yml`).
- **Local (Theos)** : `make` si `$THEOS` est défini.

## Limites (voir `../docs/LIMITES.md`)

Le spoof device est **userland** : Instagram croise d'autres signaux côté serveur
(TLS, IP, comportementaux). Ce tweak reproduit des fonctionnalités déjà publiques
(Crane, Ghost, Relocate, LSpoof) à des fins d'usage **personnel** sur appareils dont vous
êtes propriétaire.
