---
name: gitflow
description: Guide interactif GitFlow selon le cheatsheet danielkummer. À invoquer quand une opération GitFlow doit être faite (nouvelle feature, release, hotfix, merge). Vérifie la branche source, guide pas à pas.
---

# Skill : GitFlow Guide

Guide pas-à-pas pour les opérations GitFlow. Vérifie l'état, propose les commandes, rappelle le double merge.

Référence complète : `~/.claude/GITFLOW.md` + https://danielkummer.github.io/git-flow-cheatsheet/

## Opérations supportées

### Nouvelle feature

```bash
# 1. Se mettre à jour sur develop
git checkout develop
git pull

# 2. Créer la feature
git checkout -b feature/<nom-court>
# ou avec git-flow :
git flow feature start <nom-court>

# 3. ... commits ...

# 4. Finaliser
git checkout develop
git pull
git merge --no-ff feature/<nom-court>
git branch -d feature/<nom-court>
git push origin develop
# ou
git flow feature finish <nom-court>
git push origin develop
```

### Nouvelle release

```bash
# 1. Depuis develop à jour
git checkout develop
git pull

# 2. Créer la release (ex: 1.2.0)
git checkout -b release/1.2.0
# ou : git flow release start 1.2.0

# 3. Bumper version, fix mineurs, doc release notes
#    (éditer VERSION / package.json / pyproject.toml / composer.json)
#    git commit -m "chore: bump version to 1.2.0"

# 4. Merger dans main ET tagger
git checkout main
git pull
git merge --no-ff release/1.2.0
git tag -a v1.2.0 -m "Release 1.2.0"

# 5. Merger dans develop (pour récupérer les fix de release)
git checkout develop
git merge --no-ff release/1.2.0

# 6. Nettoyage
git branch -d release/1.2.0

# 7. Push (tout)
git push origin main develop --tags
```

### Nouveau hotfix

```bash
# 1. Depuis main à jour
git checkout main
git pull

# 2. Créer le hotfix
git checkout -b hotfix/<nom>
# ou : git flow hotfix start <nom>

# 3. ... correction ...
# 4. Bumper patch (1.2.0 → 1.2.1)

# 5. Merger dans main ET tagger
git checkout main
git merge --no-ff hotfix/<nom>
git tag -a v1.2.1 -m "Hotfix 1.2.1"

# 6. Merger dans develop
git checkout develop
git pull
git merge --no-ff hotfix/<nom>

# 7. Nettoyage
git branch -d hotfix/<nom>

# 8. Push
git push origin main develop --tags
```

### Bugfix (non urgent)

```bash
git checkout develop && git pull
git checkout -b bugfix/<nom>
# ... fix ...
git checkout develop
git merge --no-ff bugfix/<nom>
git branch -d bugfix/<nom>
git push origin develop
```

## Procédure interactive

Quand invoqué, je :

1. **Détecte l'état courant** :
   ```bash
   git branch --show-current
   git status --short
   git log --oneline -5
   ```

2. **Demande l'intention** si pas claire :
   - « Tu veux démarrer une feature/release/hotfix ? »
   - « Tu veux finaliser la branche courante ? »

3. **Vérifie les prérequis** :
   - Feature : dois être sur `develop`, propre, à jour
   - Release : dois être sur `develop`, propre, à jour
   - Hotfix : dois être sur `main`, propre, à jour

4. **Propose les commandes exactes** (pas exécution automatique — attente Go)

5. **Pour les merges** : rappelle systématiquement le **double merge + tag** pour release/hotfix

6. **Après merge** : propose le `git push origin main develop --tags`, **n'exécute pas sans Go**

## Vérifications à chaque opération

- [ ] `git status` propre (pas de non-commit en route)
- [ ] Sur la bonne branche source
- [ ] Branche source à jour (`git pull`)
- [ ] Tests passent avant merge
- [ ] Pour release/hotfix : version bumpée dans les fichiers pertinents
- [ ] Pour release/hotfix : double merge (main + develop)
- [ ] Pour release/hotfix : tag git posé sur main

## Red flags à signaler

- Feature créée depuis `main` au lieu de `develop`
- Hotfix créé depuis `develop` au lieu de `main`
- Release/hotfix mergée dans un seul des deux (main OU develop)
- Tag posé sur `develop` au lieu de `main`
- Commit direct sur `main` ou `develop` (le hook global bloque, mais rappel si contournement)
