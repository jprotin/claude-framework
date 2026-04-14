# GITFLOW.md — Workflow Git standardisé

Conforme au cheatsheet **danielkummer.github.io/git-flow-cheatsheet/**.

---

## Branches permanentes

| Branche | Rôle | Règles |
|---|---|---|
| `main` | Image de la production | Recevoir uniquement des merges depuis `release/*` ou `hotfix/*`. Chaque merge = un tag `vX.Y.Z`. **Aucun commit direct.** |
| `develop` | Intégration continue | Recevoir uniquement des merges depuis `feature/*`, `release/*`, `hotfix/*`, `bugfix/*`. **Aucun commit direct.** |

---

## Branches temporaires

### `feature/<nom>`
- **Créée depuis** : `develop`
- **Mergée dans** : `develop` (avec `--no-ff` recommandé)
- **Supprimée après** merge
- **Usage** : nouvelle fonctionnalité, amélioration

```bash
git checkout develop && git pull
git checkout -b feature/ma-fonctionnalite
# ... commits ...
git checkout develop && git pull
git merge --no-ff feature/ma-fonctionnalite
git branch -d feature/ma-fonctionnalite
git push origin develop
```

### `release/<version>`
- **Créée depuis** : `develop`
- **Mergée dans** : `develop` **ET** `main` (double merge)
- **Tag git** sur `main` (`v1.2.0`)
- **Supprimée après** merge
- **Usage** : stabilisation avant mise en production (bugfix mineurs, bump version, doc)

```bash
git checkout develop && git pull
git checkout -b release/1.2.0
# ... corrections mineures, bump version ...
# Merge dans main
git checkout main && git pull
git merge --no-ff release/1.2.0
git tag -a v1.2.0 -m "Release 1.2.0"
# Merge dans develop
git checkout develop
git merge --no-ff release/1.2.0
# Nettoyage
git branch -d release/1.2.0
git push origin main develop --tags
```

### `hotfix/<nom>`
- **Créée depuis** : `main`
- **Mergée dans** : `develop` **ET** `main` (double merge)
- **Tag git** sur `main` (`v1.2.1`)
- **Supprimée après** merge
- **Usage** : correctif urgent en production

```bash
git checkout main && git pull
git checkout -b hotfix/correctif-critique
# ... fix ...
# Merge dans main
git checkout main
git merge --no-ff hotfix/correctif-critique
git tag -a v1.2.1 -m "Hotfix 1.2.1"
# Merge dans develop
git checkout develop && git pull
git merge --no-ff hotfix/correctif-critique
# Nettoyage
git branch -d hotfix/correctif-critique
git push origin main develop --tags
```

### `bugfix/<nom>`
- **Créée depuis** : `develop`
- **Mergée dans** : `develop`
- **Usage** : correctif non urgent (produit non encore en prod, ou acceptable jusqu'à la prochaine release)

---

## Tags git

- **Format** : `vMAJOR.MINOR.PATCH` (SemVer)
- **Posés uniquement sur `main`** lors d'une `release/*` ou `hotfix/*`
- **Annotés** (`git tag -a`), jamais légers

---

## Outil CLI recommandé

`git-flow` AVH edition — simplifie les workflows :

```bash
# Installation (Ubuntu/Debian)
sudo apt install git-flow

# Initialisation dans un repo
git flow init -d   # accepte les defaults

# Usage
git flow feature start ma-feature
git flow feature finish ma-feature
git flow release start 1.2.0
git flow release finish 1.2.0
git flow hotfix start correctif
git flow hotfix finish correctif
```

---

## Protections automatiques (hooks Claude)

Les hooks `PreToolUse` dans `~/.claude/settings.json` vérifient :

- `git commit` sur `main` ou `develop` → **bloqué**
- `git checkout -b feature/*` hors de `develop` → **bloqué**
- `git checkout -b hotfix/*` hors de `main` → **bloqué**
- `git push --force` sur `main`/`develop` → **bloqué**
- Merge `release/*` ou `hotfix/*` → **rappel** du double merge + tag

Protections supplémentaires via `pre-commit` (hook `no-commit-to-branch`) — double filet de sécurité.

---

## Cas particuliers

- **Premier commit d'un projet** : branche `main` initialisée, puis `git checkout -b develop` avant tout travail
- **Reprise de projet existant sans GitFlow** : créer `develop` depuis `main` (`git checkout -b develop`), pousser, puis basculer le workflow
- **Feature longue** : rebase régulier sur `develop` pour limiter les conflits (`git checkout feature/x && git rebase develop`)

---

## Référence

Cheatsheet officiel : https://danielkummer.github.io/git-flow-cheatsheet/
