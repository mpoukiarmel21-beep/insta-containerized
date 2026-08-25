# Handoff OpenCode ⇄ Claude Code

> Fichier de liaison entre les deux agents. L'un met à jour, l'autre lit au démarrage.
> Les entrées les plus récentes vont en haut du Journal. Ne jamais écraser l'historique.

## État actuel

- Pont de collaboration OpenCode ⇄ Claude Code mis en place (règles globales + fichier de handoff par projet).
- Dépôt : seul `deepseek-harness/` existe, non commité.

## En cours

- **OpenCode** — prise de main le 2026-08-25 : projet INSTA. Recherche, architecture, code dylib et workflow GitHub terminés (voir journal). En attente : repo GitHub distant + IPA décryptée + secrets de signature pour build réel.

## Prochaine étape

- Attendre la prochaine demande utilisateur ; l'agent qui démarre signale sa prise de main dans cette section.

## Blocages / risques

- Aucun.

## Journal

- **2026-08-25 — OpenCode** : projet INSTA. Recherche de projets similaires (LiveContainer, LSpoof, Ghost, Azula/TrollFools/iresign, Nugget). Écriture `docs/ARCHITECTURE.md`, `docs/LIMITES.md`, `research/projets-similaires.md`. Code source de la dylib (`src/` : Tweak, ContainerManager, DeviceProfile, LocationSpoofer, FloatingButton, TweakLogger + Makefile/control/entitlements). Workflow GitHub Actions (`workflow/build-ipa.yml` + README) résolvant la limite des 334 Mo via GitHub Releases + clang/zsign. Périmètre : modding personnel (conteneurs + faux GPS + profil device), pas de contournement anti-fraude serveur. **Commit local créé** (`dc3d73e`, 24 fichiers ; `.gitignore` exclut *.ipa/secrets/deepseek-harness). Prochaine étape : repo GitHub distant + IPA décryptée + secrets pour déclencher le 1er build.

- **2026-08-25 — OpenCode** : création du protocole de collaboration (AGENTS.md racine + global, CLAUDE.md avec @import, AGENT-HANDOFF.md) et des commandes `/handoff` côté OpenCode et Claude Code.
