# 02 — Architecture technique

> **Navigation :** [← 01 Overview](01-overview.md) · [03 Mécanismes →](03-mechanisms.md) · [Accueil](../README.md)

---

## Vue en 2 couches

```
┌─────────────────────────────────────────────────────────────────┐
│                      COUCHE GLOBALE                             │
│                                                                 │
│  /datadisk/Inetum/claude-framework/    (repo git, source)      │
│  ├── CLAUDE.md, GITFLOW.md, CODING_STANDARDS.md                │
│  ├── skills/ (25)      agents/ (4)      hooks/ (4)             │
│  ├── templates/ (5)    bin/ (2)         settings.json          │
│                                                                 │
│                              ↕ symlinks                         │
│                                                                 │
│  ~/.claude/                            (points d'accès Claude) │
│  ├── CLAUDE.md → framework/CLAUDE.md                            │
│  ├── skills/   → framework/skills/                              │
│  ├── (etc.)                                                     │
│  └── [runtime non versionné : projects/, sessions/, cache/]    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼ (utilisé par)
┌─────────────────────────────────────────────────────────────────┐
│                      COUCHE PROJET                              │
│                                                                 │
│  <mon-projet>/                                                  │
│  ├── .editorconfig, .pre-commit-config.yaml  (versionnés)      │
│  ├── .gitignore (avec exclusion CLAUDE.md, .claude/)           │
│  ├── CLAUDE.md                              (GITIGNORED)        │
│  ├── .claude/                               (GITIGNORED)        │
│  ├── docs/adr/, docs/runbooks/              (versionnés)       │
│  └── [ton code]                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Couche globale : le repo `claude-framework`

### Pourquoi un repo git ?
- **Auditabilité** : chaque évolution = un commit (diff, auteur, date, raison)
- **Portabilité** : sur nouvelle machine, `git clone` + `install.sh` = tout est en place
- **Code, pas config** : les skills, hooks, scripts sont du code versionné comme tout autre projet
- **Pas de perte** : un backup externe (remote git) protège ton investissement framework

### Pourquoi des symlinks depuis `~/.claude/` ?
Claude Code cherche ses extensions **uniquement** dans `~/.claude/`. Impossible de lui dire « va voir ailleurs ». Les symlinks résolvent ça :
- Claude Code voit tout dans `~/.claude/` comme attendu
- La source reste dans `/datadisk/Inetum/claude-framework/` (versionnée)
- Modifier un skill depuis le repo → Claude le voit instantanément
- Tu peux travailler sur le framework depuis ton IDE comme sur n'importe quel projet

### Qu'est-ce qui reste **réel** dans `~/.claude/` ?

Les dossiers **runtime** gérés par Claude Code, **non versionnés** car propres à chaque machine et/ou contenant des données privées :

| Dossier/Fichier | Pourquoi pas versionné |
|---|---|
| `projects/` | Mémoire privée par projet (peut contenir noms clients, décisions internes) |
| `sessions/` | État des sessions en cours |
| `history.jsonl` | Historique de tous tes prompts (privé) |
| `cache/`, `downloads/` | Caches temporaires |
| `file-history/` | Historique de fichiers édités |
| `paste-cache/`, `plans/`, `telemetry/` | Runtime Claude |
| `shell-snapshots/`, `session-env/`, `tasks/` | Runtime Claude |
| `plugins/` | Géré par Claude Code |
| `.credentials.json` | Tokens auth |

---

## Couche projet : un repo applicatif standard

### Ce qui vit **dans** un projet (versionné)

| Fichier | Rôle | Pourquoi versionné |
|---|---|---|
| `.editorconfig` | Indent, EOL, charset | Cohérence éditeurs/contributeurs |
| `.pre-commit-config.yaml` | Hooks pre-commit (format, lint, secrets) | Enforce les normes localement et en CI |
| `.yamllint` | Config yamllint | Même raison |
| `.gitignore` | Exclusions git | Standard |
| `docs/adr/` | Architecture Decision Records | Historique des choix |
| `docs/runbooks/` | Procédures opérationnelles | Partage de connaissance |

### Ce qui est **gitignored** (présent mais non versionné)

| Fichier | Rôle | Pourquoi privé |
|---|---|---|
| `CLAUDE.md` | Contexte projet pour Claude (stack, contraintes, décisions) | Peut contenir infos sensibles / client |
| `.claude/` | Config locale Claude éventuelle | Spécifique à ton poste |

Ces deux items sont ajoutés automatique­ment à `.gitignore` par `claude-init-project.sh`.

---

## Flow d'une requête Claude — schéma

```
Tu tapes une demande
      │
      ▼
[Hook UserPromptSubmit: context-injector.sh]
      │   → injecte rappel workflow + état git
      ▼
Claude lit :
  • CLAUDE.md global (via ~/.claude/CLAUDE.md symlink)
  • CLAUDE.md projet (si présent)
  • MEMORY.md + memories pertinentes
  • Contexte repo (git log, fichiers touchés)
      │
      ▼
Claude applique le workflow :
  1. Analyse
  2. Explication
  3. Plan
  4. Attente du Go
      │
      ▼
[Tu valides]
      │
      ▼
Claude exécute → chaque outil/commande passe par :
  • [Hook PreToolUse: gitflow-guard.sh] — vérifie règles GitFlow
  • [Hook PreToolUse: danger-guard.sh]  — bloque destructif sans validation
  • [Permissions settings.json]         — allowlist / denylist
      │
      ▼
Exécution
      │
      ▼
[Hook PostToolUse: terraform-autofmt.sh] — si Edit/Write sur *.tf → format auto
      │
      ▼
Résultat renvoyé à toi
      │
      ▼
Claude décide s'il y a quelque chose à mémoriser (feedback, décision)
Si oui → écrit un fichier dans ~/.claude/projects/<projet>/memory/
```

---

## Pourquoi cette séparation global/projet ?

### Ce qui doit être **global** (dans le framework)
- **Workflow Claude** — même sur tous les projets
- **Skills et agents** — compétences universelles, réutilisées partout
- **Hooks Claude** — automations communes (GitFlow, dangers, format)
- **Scripts bin/** — outils transverses
- **Templates** — sources à dupliquer dans les projets

### Ce qui doit être **par projet** (dans le repo applicatif)
- **Contexte métier** — seul ce projet connaît sa stack précise, ses clients, ses contraintes
- **Normes de code effectives** (`.pre-commit-config.yaml`) — partagée avec une équipe/CI via le repo
- **Décisions d'architecture (ADR)** — historiques propres au projet
- **Runbooks** — procédures liées à cette app en particulier

### Ce qui doit être **privé par projet** (gitignored)
- `CLAUDE.md` projet — peut contenir deadlines internes, noms de clients, stratégies
- Mémoires Claude — contexte d'échange privé

---

## Portabilité

### Sur une nouvelle machine

```bash
git clone <url_framework> /datadisk/Inetum/claude-framework
cd /datadisk/Inetum/claude-framework
./install.sh
# → crée ~/.claude/ avec les symlinks

~/.claude/bin/claude-install-prereqs.sh
# → installe tous les outils (apt + pipx + GitHub binaries)
```

Tu retrouves exactement le même environnement.

### Pour pousser vers un remote (GitHub privé par exemple)

```bash
cd /datadisk/Inetum/claude-framework
git remote add origin git@github.com:<user>/claude-framework.git
git push -u origin main
```

### Pour mettre à jour le framework entre machines

Sur la machine où tu as fait des modifs :
```bash
cd /datadisk/Inetum/claude-framework
git add -A
git commit -m "enrich: terraform skill with MKS learnings"
git push
```

Sur l'autre machine :
```bash
cd /datadisk/Inetum/claude-framework
git pull
# Les symlinks dans ~/.claude/ voient instantanément les changements.
```

---

## Prochaines lectures

- **Comment les mécanismes fonctionnent** → [03 Mécanismes](03-mechanisms.md)
- **Voir des exemples concrets** → [05 Cas d'usage](05-use-cases.md)
