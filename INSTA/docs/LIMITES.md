# Limites techniques et périmètre

> Document de transparence. Lu avant de promettre quoi que ce soit à l'utilisateur final.

---

## 1. Ce que l'outil fera (périmètre modding personnel)

Dans le cadre d'un usage **personnel sur des appareils dont vous êtes propriétaire**, l'outil fournira :

- **Conteneurs isolés** : chaque conteneur = un répertoire sandbox + un groupe Keychain dédié. Équivalent open-source de Crane / LiveContainer.
- **Faux GPS par conteneur** : hook de `CLLocationManager` (technique publique type LSpoof / Relocate). Carte + recherche + zoom + « Activer ».
- **Profil device par conteneur** : spoof userland de `UIDevice`, `uname`, `sysctl` (technique publique type Ghost).
- **Persistance** : les comptes connectés restent après fermeture/relance (écriture dans le vrai `NSHomeDirectory()` du conteneur + keychain group dédié).
- **Reset global** : purge totale des conteneurs + keychain.

Tout ceci reproduit des fonctionnalités **déjà publiques et distribuées** (Crane, Ghost, Relocate2, LSpoof, LiveContainer).

---

## 2. Ce qui dépasse les capacités techniques réelles (ne pas promettre)

| Promesse impossible | Réalité technique |
|---|---|
| « Instagram ne détectera jamais la modif » | Faux. Instagram/Meta croise TLS, IP, comportement, et faisceaux de signaux serveur. Aucun hook userland ne cache tout. |
| « Créer des comptes à l'infini sans jamais être bloqué » | Faux. Les défenses anti-fraude côté serveur (comportementales + device attestation) ne sont pas contournables par une dylib userland. |
| « Device 100 % invisible » | Ghost seul échoue déjà sur IG (retours r/jailbreak 2026). Le spoof userland ne tient pas face aux checks cohérence. |
| « Aucun bug jamais » | Irréaliste. Chaque MAJ Instagram peut casser un hook. Maintenance continue requise. |

---

## 3. Dépendances externes non négociables

1. **IPA décryptée** : sans ça, rien n'est modifiable (DRM FairPlay). À obtenir depuis un device jailbreaké.
2. **Compte Apple + certificat** : signature obligatoire. Gratuit = 7 jours. Payant (Developer Program) = 1 an.
3. **Proxy** : l'utilisateur gère le sien (hors périmètre code).

---

## 4. Risques assumés par l'utilisateur

- Violation des CGU Instagram (risque de ban de compte).
- Révocation possible du certificat Apple si abus.
- Instabilité liée aux MAJ Instagram.

Ces risques ne sont pas des bugs du code : ils sont structurels.
