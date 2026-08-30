# PROJETOPENCODE

Dépôt de travail partagé entre **OpenCode** et **Claude Code**. Les deux agents alternent sur les mêmes projets — le contenu actuel (`deepseek-harness/`) est un espace de travail, pas encore commité.

## Règle anti-arrêt (Règle A : Complétion forcée) — à appliquer TOUJOURS

- **Une fois une tâche commencée, on va jusqu'au bout de l'objectif** (ex. build CI vert, IPA vérifié HTTP 200, handoffs poussés, lien livré) avant de s'arrêter.
- **On passe à "terminé" UNIQUEMENT quand le travail est réellement fini et vérifié** — jamais sur simple intention.
- **Aucune réponse-vide / aucun préambule redondant** : pas de répétition "Let me… / je vais faire…" sans appel d'outil immédiat.
  - **Une intention = un appel d'outil.** Si on déclare "je vais X", le message suivant DOIT contenir l'exécution de X.
  - Chaque lot d'appels doit produire un résultat vérifiable.
- **En cas de blocage réel** : le dire en UNE seule phrase, puis changer de méthode de suite (autre outil, autre question) — jamais rester en boucle sur le même échec.
- **Ambigüité** : poser une seule question via l'outil dédié, puis exécuter quoi qu'il arrive jusqu'au bout.
- **Mémoire légère** : garder la connaissance globale du projet, les chemins et les accès (voir + bas), mais pas les dialogues intermédiaires.

## Connaissances globales du projet (à conserver)

- **Vault** = tweak iOS (Theos/theos-jailed) répliquant un système de gestion multi-comptes sur un hôte.
  On **copie verbatim** `whaminsta\Tweak\Source` → cible `Tweak\Source`, puis on adapte : hôte (bundleId), marque, tailles UI.
- **Fichiers réutilisables** : `IVPanelVC.m` (menu/marque/toggle FR-EN/titleView), `IVFloatingButton.m`, `IVCreateVC.m`, `IVMapPickerVC.m`, `IVCameraHook`, `IVHardening`, `IVAppRelaunch`, `IVLocaleSpoof`, `IVAppGroupHook`, `IVPaths`, `IVDiagnostics`, `IVTheme`.
- **Hôte = bundleId** : Instagram `com.burbn.instagram` ; Threads `com.burbn.barcelona` (à changer dans `IVLocaleSpoof.m`, `IVAppGroupHook.m`, Makefile).
- **Marque visible** : chaînes `@"..."` de marque dans `IVPanelVC.m` (`self.title`, `word.text`, `makeBrandTitleView`) et `IVFloatingButton.m` (accessibilityLabel). Namespace interne `whaminsta` laissé tel quel.
- **Toggle FR/EN** : `IVPanelVC.m` `makeLangToggle`, ancré à gauche après le bouton ✕ (actuellement `40×18` @9 pt).
- **Base de build** configurable via l'input `ipa_url` du workflow `build.yml` de la cible.

## Accès / chemins (à conserver)

- Racine : `D:\opencode\PROJETOPENCODE\`
- **whaminsta** (source/Instagram, build-8, base 442.0.0) : `…\whaminsta` → repo `mpoukiarmel21-beep/whaminsta`
- **ThreadsVault** (Threads ; repo renommé `Whamthreads`) : `…\ThreadsVault` → repo `mpoukiarmel21-beep/Whamthreads` (dossier local nommé `ThreadsVault`)
- **INSTA** (liaison) : `…\INSTA` → repo `mpoukiarmel21-beep/insta-containerized`
- GitHub CLI auth `mpoukiarmel21-beep` ; `gh` pour rename/workflow/release. Shell PowerShell.
- Tool `changed-files` cassé → suivre via `git status`.
- Handoffs à jour à chaque unité : `AGENT-HANDOFF.md` (racine projet) + `INSTA\AGENT-HANDOFF.md`. Ne jamais écraser l'historique (journal daté en haut).

## Collaboration

- Lis `AGENT-HANDOFF.md` avant de commencer : il contient l'état courant, la prochaine étape et le journal des interventions.
- Mets-le à jour après chaque unité de travail significative (voir protocole global).
- Claude Code charge ce fichier via `CLAUDE.md` (@import), donc les deux agents partagent exactement les mêmes règles et le même état.

## Conventions

- Ne commite `deepseek-harness/` que sur demande explicite de l'utilisateur.
- Les chemins Windows sont la norme ici ; préférer PowerShell pour les commandes shell.
