# 07 — Cookbook (recettes pratiques)

> **Navigation :** [← 06 Référence](06-reference.md) · [Accueil](../README.md)

Recettes courtes, actionnables, organisées par besoin.

---

## Setup

### Installer sur une nouvelle machine

```bash
# 1. Cloner le framework
git clone <url> /[path-folder-projects]/claude-framework
cd /[path-folder-projects]/claude-framework

# 2. Installer les symlinks ~/.claude/
./install.sh

# 3. Installer les outils prérequis
~/.claude/bin/claude-install-prereqs.sh

# 4. Vérifier PATH
echo $PATH | tr ':' '\n' | grep '.local/bin'
# Si absent :
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Vérifier que tout fonctionne
```bash
ls -la ~/.claude/                              # doit montrer les symlinks
~/.claude/bin/claude-install-prereqs.sh --check  # audit outils
# Dans Claude Code, tape /architect → doit reconnaître le skill
```

---

## Gestion projet

### Bootstraper un nouveau projet

```bash
mkdir /[path-folder-projects]/mon-projet
cd /[path-folder-projects]/mon-projet
~/.claude/bin/claude-init-project.sh
```

### Bootstraper un projet existant (non-destructif)

```bash
cd /chemin/projet-existant
~/.claude/bin/claude-init-project.sh
# Les fichiers existants ne sont pas écrasés, sauf avec --force
```

### Choisir les outils à installer pour un projet

Projet JS seulement : pas besoin du groupe PHP/Terraform.

```bash
~/.claude/bin/claude-install-prereqs.sh --interactive
# → choix groupe par groupe
```

Ou directement :
```bash
~/.claude/bin/claude-install-prereqs.sh --groups core,secrets,python
```

---

## Git / GitFlow

### Démarrer une feature

```bash
git checkout develop && git pull
git checkout -b feature/ma-feature
# ... travail ...
```

Ou via git-flow :
```bash
git flow feature start ma-feature
```

Ou via Claude : « démarre une feature `ma-feature` » → `/gitflow` guide.

### Finaliser une feature

```bash
git checkout develop && git pull
git merge --no-ff feature/ma-feature
git branch -d feature/ma-feature
git push origin develop
```

### Préparer une release

```bash
git checkout develop && git pull
git checkout -b release/1.2.0

# Bumper version dans fichiers (pyproject.toml / package.json / composer.json)
# Corrections mineures

# Double merge + tag
git checkout main && git pull
git merge --no-ff release/1.2.0
git tag -a v1.2.0 -m "Release 1.2.0"

git checkout develop
git merge --no-ff release/1.2.0

git branch -d release/1.2.0
git push origin main develop --tags
```

### Lancer un hotfix

```bash
git checkout main && git pull
git checkout -b hotfix/correctif

# ... fix + bump patch ...

git checkout main
git merge --no-ff hotfix/correctif
git tag -a v1.2.1 -m "Hotfix 1.2.1"

git checkout develop && git pull
git merge --no-ff hotfix/correctif

git branch -d hotfix/correctif
git push origin main develop --tags
```

### Commit avec message soigné

Dans Claude Code : `/commit`

Claude va :
- Lire `git diff --staged`
- Analyser type, scope, pourquoi
- Te proposer un message (libre ou Conventional au choix)
- Commiter après ton Go

---

## Compétences Claude

### Obtenir un avis d'architecte

```
/architect

Question : «Monolithe vs micro-services pour notre app de 5 devs ?»
```

### Obtenir un audit sécurité

```
Utilise le sous-agent security-auditor sur ce repo.
```

### Obtenir un plan de tests

```
Utilise test-designer sur src/myapi/payments.py pour me proposer
une stratégie de tests.
```

### Faire une revue avant commit

```
/review
```

Claude applique la checklist qualité/sécurité/tests/doc et te liste bloquants/recos.

### Déboguer méthodiquement

```
/debug

Problème : «les requêtes timeout aléatoirement, 1 sur 50.»
```

### Documenter une décision

```
/adr

Sujet : choix du cache applicatif
Option A : Redis local
Option B : DynamoDB cache
Retenue : A pour simplicité
```

---

## Mémoire

### Sauvegarder le contexte avant un break

```
/save-context
```

### Recharger après un reboot / congés

```
/load-context
```

### Retenir une préférence manuelle

```
Retiens que j'utilise toujours pnpm et pas npm.
```
→ Claude écrit `feedback_pnpm_over_npm.md`

### Oublier une info périmée

```
Oublie la préférence sur l'outil X, on a changé de stack.
```
→ Claude supprime ou met à jour la memory concernée.

### Voir ce qui est mémorisé pour ce projet

```bash
ls ~/.claude/projects/$(echo -n "$PWD" | md5sum | cut -c1-32)/memory/ 2>/dev/null
# ou plus simple :
ls ~/.claude/projects/-*$(basename "$PWD")*/memory/ 2>/dev/null
```

---

## Enrichir le framework

### Enrichir un skill après un apprentissage

Après une session où tu as appris quelque chose d'utile sur Terraform :
```
/skill-enrich terraform
```

Claude va :
- Distiller l'apprentissage en règle actionnable
- Ajouter à `~/.claude/skills/terraform/SKILL.md` section `## Learnings`
- Te montrer le diff
- Attendre ton Go pour commit dans le framework

### Ajouter un nouveau skill

```bash
mkdir /[path-folder-projects]/claude-framework/skills/mon-skill
cat > /[path-folder-projects]/claude-framework/skills/mon-skill/SKILL.md <<'EOF'
---
name: mon-skill
description: [quand l'invoquer, déclencheurs]
---

# Skill : <titre>

## Principes
...

## Procédure
...

## Learnings
EOF

# Commit dans le framework
cd /[path-folder-projects]/claude-framework
git add skills/mon-skill
git commit -m "Ajoute skill mon-skill"
```

### Modifier un hook

```bash
vim /[path-folder-projects]/claude-framework/hooks/gitflow-guard.sh
# Les symlinks font que ~/.claude/hooks/gitflow-guard.sh reflète instantanément
# Tester :
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
    | ~/.claude/hooks/gitflow-guard.sh
echo "exit code: $?"
```

---

## Troubleshoot

### Un symlink ~/.claude/ est cassé

```bash
# Diagnostic
ls -la ~/.claude/CLAUDE.md
# doit pointer vers /[path-folder-projects]/claude-framework/CLAUDE.md

# Réparer tous les symlinks
cd /[path-folder-projects]/claude-framework
./install.sh --force
```

### Un hook ne se déclenche pas

```bash
# Vérifier qu'il est déclaré
cat ~/.claude/settings.json | jq '.hooks'

# Vérifier qu'il est exécutable
ls -l /[path-folder-projects]/claude-framework/hooks/
# doit être rwxr-xr-x

# Tester manuellement
echo '{"tool_name":"Bash","tool_input":{"command":"git commit"}}' \
    | ~/.claude/hooks/gitflow-guard.sh
echo "exit: $?"
```

### `pre-commit run` échoue sur un hook

```bash
# Voir quel hook pose souci
pre-commit run --all-files --verbose

# Skipper temporairement un hook
SKIP=terraform_checkov pre-commit run --all-files

# Mettre à jour les repos pre-commit
pre-commit autoupdate
```

### Un skill n'est pas reconnu par Claude Code

```bash
ls -la ~/.claude/skills/<nom>/SKILL.md
# doit exister et être lisible

cat ~/.claude/skills/<nom>/SKILL.md | head -10
# front-matter YAML correct : ---\nname: <nom>\ndescription: ...\n---
```

### `terraform fmt` ne se déclenche pas automatiquement

Vérifier que le hook PostToolUse matche bien :
```bash
cat ~/.claude/settings.json | jq '.hooks.PostToolUse'
```
Le matcher doit être `"Edit|Write|MultiEdit"` et le fichier doit avoir extension `.tf`.

### Le repo framework a un état bizarre

```bash
cd /[path-folder-projects]/claude-framework
git status
git log --oneline -5
# Si besoin de repartir propre sans perdre les modifs :
git stash
# Ou voir le diff :
git diff
```

---

## Update du framework

### Mettre à jour depuis le remote

```bash
cd /[path-folder-projects]/claude-framework
git fetch && git log --oneline HEAD..origin/main   # voir ce qui arrive
git pull
# Les symlinks voient instantanément les changements
```

### Pousser tes modifs locales

```bash
cd /[path-folder-projects]/claude-framework
git status
git add -A
git commit -m "enrich: ..."
git push
```

### Mettre à jour les outils

```bash
~/.claude/bin/claude-install-prereqs.sh --upgrade
```

---

## Usage avancé

### Désactiver un skill temporairement

```bash
mv ~/.claude/skills/<nom> ~/.claude/skills/.<nom>-disabled
# Claude ne le voit plus, les autres fonctionnent
```

### Travailler hors GitFlow sur un projet

Pas besoin d'action : si le repo n'a pas de branche `develop`, les règles GitFlow sont automatique­ment désactivées par `gitflow-guard.sh`.

### Scan secret dans l'historique git

```bash
cd <projet>
gitleaks detect --log-opts="--all"   # full history
```

### Audit un projet existant

```bash
cd <projet>
pre-commit run --all-files           # tous les hooks
~/.claude/bin/claude-install-prereqs.sh --check  # outils présents ?
```

### Partager un template de skill entre membres d'équipe

Le framework est ton outil perso. Pour partager avec une équipe :
1. Fork le framework en org
2. Chaque membre clone + `install.sh`
3. Les améliorations remontent via PR sur le repo partagé

---

## Convention de nommage

### Skills
- Action ou rôle en un mot : `debug`, `architect`, `terraform`
- Lowercase, kebab-case si 2 mots : `save-context`, `load-context`

### Branches
- `feature/<slug-court>` — snake-case ou kebab-case, descriptif
- `release/<version>` — version SemVer (`1.2.0`)
- `hotfix/<slug-court>` — même convention que feature
- `bugfix/<slug-court>` — comme feature, pour bugs non urgents

### Tags
- `v<MAJOR>.<MINOR>.<PATCH>` — SemVer strict, annotés

### Memories
- `user_<sujet>.md` — profil durable
- `feedback_<sujet>.md` — préférences/règles
- `project_<sujet>.md` — état projet
- `reference_<sujet>.md` — pointeur externe

---

## Checklist release-ready d'un projet

Avant de tagguer `v1.0.0` en prod :

- [ ] `pre-commit run --all-files` vert
- [ ] Tests unitaires verts (> 70% coverage sur code critique)
- [ ] Sous-agent `security-auditor` lancé → 0 critique
- [ ] Sous-agent `code-reviewer` lancé sur le diff main..develop
- [ ] Sous-agent `doc-sync` lancé → pas de divergences critiques
- [ ] CHANGELOG.md à jour
- [ ] ADR à jour pour les décisions structurantes
- [ ] Runbook d'incident présent (au moins 1 — "que faire si l'app plante")
- [ ] Backup / restore testé (pour les apps avec données)
- [ ] Secrets vérifiés : `gitleaks detect --log-opts="--all"` clean
- [ ] Monitoring / alerting en place

---

## Retour à l'accueil

[← README](../README.md) · [01 Overview](01-overview.md)
