# 03 — Mécanismes

> **Navigation :** [← 02 Architecture](02-architecture.md) · [04 Workflow →](04-workflow.md) · [Accueil](../README.md)

Les 6 mécanismes qui font tourner le framework.

---

## 1. `CLAUDE.md` — Instructions Claude

### Rôle
Fichier markdown chargé automatiquement dans le contexte de Claude à chaque session. C'est la **source de vérité** pour son comportement.

### Niveaux
| Niveau | Chemin | Portée |
|---|---|---|
| **Global** | `~/.claude/CLAUDE.md` (→ framework) | Tous les projets, toutes les sessions |
| **Projet** | `<projet>/CLAUDE.md` (gitignored) | Ce projet seulement, override/complète le global |

### Ce qu'on y met
- **Oui** : workflow à respecter, règles de sécurité, conventions de style de réponse, pointeurs vers skills/docs
- **Oui** : contexte projet (objectif, stack, contraintes)
- **Non** : listes exhaustives de commandes (celles-ci vont dans les skills)
- **Non** : secrets, clés, tokens
- **Non** : info dérivable du code (git log, README, structure)

### Pourquoi c'est puissant
Une règle dans `CLAUDE.md` est **absolue** : Claude la lit à chaque session, pas besoin de la répéter. C'est la différence entre une préférence qu'on oublie et une règle durable.

---

## 2. Hooks — Automatisations système

### Principe
Ce sont des **scripts shell exécutés par Claude Code** (pas par Claude lui-même) en réponse à des événements. C'est le seul mécanisme qui permet de **forcer** un comportement ou de **bloquer** une action.

### Événements supportés
| Événement | Quand | Usage typique |
|---|---|---|
| `UserPromptSubmit` | Avant que Claude voie ton prompt | Injecter du contexte système |
| `PreToolUse` | Avant exécution d'un outil (Bash, Edit…) | Bloquer/valider une action |
| `PostToolUse` | Après exécution d'un outil | Auto-format, log |
| `Stop` | Fin de session | Cleanup, snapshot |

### Nos 4 hooks

#### `context-injector.sh` (`UserPromptSubmit`)
À chaque prompt, ajoute au contexte Claude :
- Rappel du workflow analyse → plan → Go
- Rappel de la règle « jamais de commit/push sans Go »
- Règles GitFlow
- État git courant (branche, modifications en cours, ahead/behind)

**Effet** : même après 50 échanges, Claude n'oublie pas les règles.

#### `gitflow-guard.sh` (`PreToolUse` sur `Bash`)
Intercepte chaque commande bash et **bloque** :
- `git commit` si branche = `main` / `master` / `develop` (uniquement si `develop` existe = GitFlow actif)
- `git checkout -b feature/*` si la branche source n'est pas `develop`
- `git checkout -b hotfix/*` si la branche source n'est pas `main`
- `git checkout -b release/*` si la branche source n'est pas `develop`
- `git push --force` sur `main` / `develop`
- Rappelle le **double merge** sur merge de `release/*` ou `hotfix/*`

#### `danger-guard.sh` (`PreToolUse` sur `Bash`)
Bloque :
- `rm -rf` hors chemins safe (`/tmp`, `node_modules`, `.cache`, `dist`, `build`)
- `git reset --hard`
- `git branch -D`
- `terraform apply` / `terraform destroy`
- `kubectl delete` sans `--dry-run`
- `DROP TABLE` / `TRUNCATE TABLE`
- `--no-verify` (bypass hooks)

**Intention** : forcer Claude à demander une validation explicite pour chaque opération destructrice.

#### `terraform-autofmt.sh` (`PostToolUse` sur `Edit|Write|MultiEdit`)
Après chaque édition d'un `*.tf` / `*.tfvars` / `*.hcl`, lance `terraform fmt` silencieusement. Format garanti sans effort.

---

## 3. Skills — Compétences à la demande

### Principe
Un skill = un dossier `~/.claude/skills/<nom>/` contenant un `SKILL.md` avec :
- **Front-matter YAML** : `name`, `description` (c'est par la description que Claude décide de l'invoquer)
- **Contenu** : prompt expert + checklist + patterns + red flags

### Invocation
- **Explicite** : tu tapes `/architect`, `/terraform`, `/debug` dans Claude Code
- **Auto-déclenché** : si la description du skill matche ce que tu demandes, Claude peut le proposer ou l'invoquer

### Catégories
| Type | Skills | Rôle |
|---|---|---|
| **Métiers** | architect, sre, devops, security, dba | Endosser un rôle expert |
| **Technos** | terraform, ansible, kubernetes, linux, docker, python, bash, javascript, typescript, php | Stack-specific |
| **Processus** | analyze, review, debug, commit, gitflow, adr, save-context, load-context, onboard-project, skill-enrich | Outils méta |

### Anatomie d'un skill

```markdown
---
name: architect
description: Endosse le rôle de Solution Architect. À invoquer pour…
---

# Skill : Solution Architect

## Principes directeurs
- …

## Méthode d'analyse (ordre strict)
1. Besoin métier
2. Contraintes…

## Red flags
- « Ça va scaler » sans chiffres
- Micro-services pour < 5 devs

## Format de réponse attendu
<template à suivre>

## Learnings
<!-- Enrichi au fil de l'eau via /skill-enrich architect -->
```

### Enrichissement continu
La section `## Learnings` s'enrichit via `/skill-enrich <nom>` à chaque fois qu'on découvre un pattern, piège, ou bonne pratique spécifique. Le skill devient **plus intelligent** avec le temps.

---

## 4. Sous-agents — Revues indépendantes

### Principe
Un sous-agent est lancé par Claude comme un **processus isolé** qui démarre avec son propre prompt et sans le contexte de la conversation principale. Il donne donc un avis **non contaminé**.

### Nos 4 sous-agents

| Agent | Déclencheur | Usage |
|---|---|---|
| `code-reviewer` | Avant commit/merge significatif | Revue qualité/correction/sécurité d'un diff |
| `security-auditor` | Avant release, zone sensible touchée | Audit sécurité (secrets, vulns, surface d'attaque) |
| `doc-sync` | Après changement structurel | Détection divergences code ↔ doc |
| `test-designer` | Avant d'écrire des tests | Plan de tests priorisé pour un changement |

### Quand Claude les utilise
- Quand tu le demandes explicitement (« fais-moi reviewer par code-reviewer »)
- **Proactivement** : si tu as modifié un module important, Claude peut proposer de lancer `code-reviewer` avant de commiter

---

## 5. Auto-memory — Persistance entre sessions

### Rôle
Claude **sauvegarde automatiquement** des informations qui doivent persister entre sessions, dans :
```
~/.claude/projects/<hash-du-projet>/memory/
├── MEMORY.md              # index (toujours lu au démarrage)
├── user_profile.md        # qui tu es, comment tu veux collaborer
├── feedback_*.md          # règles/préférences validées
├── project_*.md           # état projet, décisions, contraintes
└── reference_*.md         # pointeurs vers systèmes externes
```

### Types de mémoire
| Type | Quoi | Exemple |
|---|---|---|
| `user` | Durable sur toi | "Travaille en solo, projets IaC" |
| `feedback` | Règle/préférence validée | "Commits en format libre par défaut" |
| `project` | État projet, décisions | "Module MKS en cours sur branche feature/mks" |
| `reference` | Pointeur externe | "Bugs pipeline tracés dans Linear INGEST" |

### Règles de sauvegarde auto (sans te demander)
Claude mémorise quand tu :
- Le corriges (« non, pas ça »)
- Valides explicitement un choix non évident (« oui exactement »)
- Partages une info durable (rôle, niveau, deadline)
- Mentionnes un système externe (Jira, Grafana…)

### Ce qui n'est pas sauvé
- Architecture / structure du code (dérivable du code)
- Git log / who-changed-what (`git log` / `git blame`)
- Solutions de debug ponctuelles (le fix est dans le code)

---

## 6. `settings.json` — Permissions + hooks

### Rôle
Config Claude Code qui définit :
- **Permissions** : allowlist / denylist de commandes Bash (les allowlistées ne demandent pas confirmation)
- **Hooks** : quel script lancer sur quel événement

### Notre allowlist (extraits)
Commandes non destructives lues/monitoring, approuvées sans prompt :
- `git status`, `git diff`, `git log`, `git branch`
- `terraform fmt/validate/plan/show/state list/output`
- `kubectl get/describe/logs/config/diff`
- `docker ps/images/logs/inspect`
- Tous les linters : `shellcheck`, `hadolint`, `yamllint`, `markdownlint`, `sqlfluff`, `eslint`, `phpstan`, etc.
- Audit deps : `npm audit`, `pip-audit`, `composer audit`
- `pre-commit run`, `gitleaks detect`, `detect-secrets scan`

### Notre denylist
Commandes toujours bloquées même si Claude les tente :
- `git push --force` / `git push -f`
- `rm -rf /*`
- `sudo rm:*`
- `dd if=*`, `mkfs:*`

---

## Comment ces mécanismes collaborent

Exemple réel : tu demandes « ajoute une feature auth »

1. **Hook `context-injector`** : rappelle le workflow à Claude
2. **Claude lit `CLAUDE.md`** (global + projet) + memory → comprend le contexte
3. **Claude applique le workflow méta** (analyse → plan → attente Go)
4. Tu donnes le Go
5. **Hook `gitflow-guard`** : Claude tente `git checkout -b feature/auth` → vérifie que la branche source est `develop` → OK
6. Claude écrit le code, édite des fichiers
7. Si Claude édite un `.tf` → **hook `terraform-autofmt`** le formate
8. Claude invoque **sous-agent `code-reviewer`** avant de proposer le commit
9. Claude invoque le **skill `/commit`** pour proposer un message
10. **Hook `gitflow-guard`** : `git commit` OK (on est sur `feature/auth`, pas sur `develop`)
11. **Hook `danger-guard`** : pas de `--no-verify`, OK
12. Commit effectué
13. Claude détecte que tu as validé le pattern « PR squash-merge » → sauvegarde en `feedback_merge_strategy.md` (auto-memory)

---

## Prochaines lectures

- **Le workflow détaillé** → [04 Workflow](04-workflow.md)
- **Voir ça sur des cas d'usage** → [05 Cas d'usage](05-use-cases.md)
