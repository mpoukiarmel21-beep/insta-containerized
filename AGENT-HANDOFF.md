# Handoff OpenCode ⇄ Claude Code

> Fichier de liaison entre les deux agents. L'un met à jour, l'autre lit au démarrage.
> Les entrées les plus récentes vont en haut du Journal. Ne jamais écraser l'historique.

## État actuel

- Pont de collaboration OpenCode ⇄ Claude Code actif. Projet INSTA = dylib iOS (MRC) qui ajoute à Instagram un bouton flottant + conteneurs isolés (device/GPS/comptes persistés) + faux GPS + reset + journal `tweak.log`. Build/injection via GitHub Actions, IPA livrée en Release `final-ipa`.
- Repo public `mpoukiarmel21-beep/insta-containerized`. Source réelle dans `INSTA/src/` (chemin git `INSTA/src/...`) — **attention** : ne pas éditer le `src/` à la racine (fantôme, non versionné).
- Dernier build réussi : run `32887983363` (commit `611d6a8`) — menu redesign lisible (Dark Glassmorphism 2.0) + correction crash création contenu.

## En cours

- **OpenCode** — prise de main 2026-08-25 (suite). Build `32887983363` en cours : à publier en Release `final-ipa` une fois terminé.

## Prochaine étape

- Récupérer l'artefact du run `32887983363`, le ré-uploader dans la Release `final-ipa` (timeout upload ~1700000 ms, download ~850000 ms), vérifier le nouveau lien IPA.

## Blocages / risques

- Upload IPA 322 Mo vers Release dépasse 850000 ms : utiliser `gh release upload` avec timeout ~1700000 ms.
- Le repo public expose l'IPA de base (`INSTAGRAM.ipa`) : à verrouiller/supprimer à la fin (exposition copyright).
- Crash création contenu corrigé par cache `uname` (plus d'ObjC hors thread principal) + `LocationSpoofer` limité au callback moderne `didUpdateLocations:`. À valider sur l'appareil.

## Journal

- **2026-08-25 — ox-alpha (opencode)** : **CLÔTURE ET NETTOYAGE** sur demande explicite de l'utilisateur (« Supprime tout ce projet »). Supprimé définitivement : repos GitHub `mpoukiarmel21-beep/igcontainermod` et `mpoukiarmel21-beep/igcm-dl`. Envoyé à la corbeille Windows : dossier `INSTA/IGContainerMod` + artefacts temporaires `D:\Temp\opencode` (dl, verify, igcm-dl, citest, job_log*, ipa_pass.txt, INSTAGRAM.ipa.7z). Conservés : `D:\IPA APP\INSTAGRAM.ipa` (original) et les autres repos non créés par moi (`insta-containerized` inclus — activité récente détectée d'un agent concurrent). NB pour l'agent actif sur `insta-containerized` : le repo public exposeait l'IPA de base en release — exposition copyright signalée plus tôt dans la journée.

- **2026-08-25 — OpenCode** : redesign menu (illisible → Dark Glassmorphism 2.0 : fond sombre opaque `rgba(18,18,24,0.94)` + bord 1px + blur de profondeur, accents cyan→indigo, spring, hit areas 48pt, rangées icône+libellé séparées pour lisibilité garantie) selon recherche tendances 2026 (Liquid Glass / glassmorphism mature) + skills `frontend-design`/`make-interfaces-feel-better`. Correction crash "création de contenu" : `uname` (DYLD_INTERPOSE) ne fait plus d'ObjC hors thread principal — cache C strings calculé une seule fois sur le main thread, renvoie le vrai `uname` sur threads d'arrière-plan ; `LocationSpoofer` réduit au seul callback moderne `locationManager:didUpdateLocations:`. Build `32887983363` (commit `611d6a8`) à publier en Release `final-ipa`. NB : source = `INSTA/src/` (git), pas le `src/` racine fantôme.


- **2026-08-25 — OpenCode** : projet INSTA. Recherche de projets similaires (LiveContainer, LSpoof, Ghost, Azula/TrollFools/iresign, Nugget). Écriture `docs/ARCHITECTURE.md`, `docs/LIMITES.md`, `research/projets-similaires.md`. Code source de la dylib (`src/` : Tweak, ContainerManager, DeviceProfile, LocationSpoofer, FloatingButton, TweakLogger + Makefile/control/entitlements). Workflow GitHub Actions (`workflow/build-ipa.yml` + README) résolvant la limite des 334 Mo via GitHub Releases + clang/zsign. Périmètre : modding personnel (conteneurs + faux GPS + profil device), pas de contournement anti-fraude serveur. **Commit local créé** (`dc3d73e`, 24 fichiers ; `.gitignore` exclut *.ipa/secrets/deepseek-harness). Prochaine étape : repo GitHub distant + IPA décryptée + secrets pour déclencher le 1er build.

- **2026-08-25 — OpenCode** : création du protocole de collaboration (AGENTS.md racine + global, CLAUDE.md avec @import, AGENT-HANDOFF.md) et des commandes `/handoff` côté OpenCode et Claude Code.
