# Workflow de build de l'IPA Instagram containerisée

Pipeline GitHub Actions (runner `macos-latest`). Produit une IPA avec la dylib
injectée + signature ad-hoc. **Sideloadly re-signe l'IPA avec ton Apple ID lors
de l'install sur l'iPhone** — aucun certificat/secret n'est nécessaire ici.

## Étapes du pipeline (`build-ipa.yml`)
1. Télécharge `INSTAGRAM.ipa` depuis la Release GitHub `base-ipa`.
2. Dézippe le bundle.
3. Compile `insert_dylib` (injecteur Mach-O).
4. Compile `Tweak.dylib` (clang + SDK iPhone, arm64).
5. Injecte `@executable_path/Frameworks/Tweak.dylib` (weak) + signature ad-hoc + entitlements.
6. Re-paquette `Instagram-Containerized.ipa` → artefact téléchargeable.

## Ce qu'il te faut fournir (côté toi)
- Une **IPA Instagram décryptée** (FairPlay retiré, ex : depuis un iPhone jailbreaké),
  uploadée une fois en Release `base-ipa` :
  `gh release create base-ipa INSTAGRAM.ipa --title "Base Instagram IPA"`
- Lancer le workflow (`Actions` → `Build Instagram Containerized IPA` → Run workflow).
- Récupérer l'artefact `Instagram-Containerized.ipa` et l'ouvrir dans **Sideloadly**
  (Apple ID gratuit = 7 jours, Developer Program = 1 an).

## Notes
- L'IPA de 334 Mo vit en GitHub Release (limite 2 Go), jamais dans git (voir `.gitignore`).
- Le spoof device/GPS est userland : il reproduit des tweaks publics (Crane/Ghost/LSpoof)
  pour un usage personnel. Il ne « rend pas Instagram invisible » côté serveur (voir `docs/LIMITES.md`).
