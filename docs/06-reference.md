# 06 — Référence

> **Navigation :** [← 05 Cas d'usage](05-use-cases.md) · [07 Cookbook →](07-cookbook.md) · [Accueil](../README.md)

Liste exhaustive de tout ce que le framework propose, avec le rôle de chaque item en une ligne. Cherche ce dont tu as besoin au `Ctrl-F`.

---

## Skills

### Métiers

| Skill | Rôle |
|---|---|
| `/architect` | Solution Architect : trade-offs, ADR, capacity model, threat model STRIDE |
| `/sre` | Site Reliability Engineer : SLO/SLI, 4 golden signals, post-mortems, runbooks |
| `/devops` | DevOps / Platform : pipelines CI/CD, IaC, GitOps, DORA metrics |
| `/security` | Security Engineer : OWASP top 10, threat model, secrets, conformité |
| `/dba` | DBA / Data Engineer : schéma, index, migrations, backups, perf SQL |

### Technos

| Skill | Rôle |
|---|---|
| `/terraform` | Modules, state, workspaces, drift, tfsec, patterns HCL |
| `/ansible` | Playbooks, roles, idempotence, vault, FQCN, Molecule |
| `/kubernetes` | Deployments production-grade, RBAC, NetworkPolicy, Helm, multi-AZ |
| `/linux` | systemd, networking, perf troubleshooting, LVM, audit |
| `/docker` | Multi-stage, sécurité image, buildkit, compose, debugging |
| `/python` | Python 3.10+, typing, pytest, ruff, uv, async |
| `/bash` | Scripting robuste, strict mode, arg parsing, bats |
| `/javascript` | JS moderne ES2023+, Node LTS, ESM, vitest |
| `/typescript` | TS 5.x strict, generics, Zod, discriminated unions |
| `/php` | PHP 8.2+, PSR-12, phpstan level 8, Laravel/Symfony patterns |

### Processus

| Skill | Rôle |
|---|---|
| `/analyze` | Force le workflow méta (analyse → plan → Go) sur une demande |
| `/review` | Revue pré-livraison structurée (qualité, sécurité, tests, doc) |
| `/debug` | Méthode structurée : repro → isoler → hypothèse → test → fix (cause racine) |
| `/commit` | Aide à formuler un message de commit soigné (libre ou Conventional) |
| `/gitflow` | Guide interactif pour opérations GitFlow (feature/release/hotfix) |
| `/adr` | Génère un Architecture Decision Record dans `docs/adr/` |
| `/save-context` | Snapshot du contexte courant en auto-memory |
| `/load-context` | Re-synchro complète du contexte après reboot/gap |
| `/onboard-project` | Bootstrap d'un projet avec le stack standard |
| `/skill-enrich` | Enrichit la section `## Learnings` d'un skill existant |

---

## Sous-agents

| Agent | Invocation | Rôle |
|---|---|---|
| `code-reviewer` | Auto par Claude avant commits significatifs, ou à la demande | Revue qualité/correction/sécurité indépendante |
| `security-auditor` | À la demande avant release ou zones sensibles | Audit sécurité complet (gitleaks, tfsec, OWASP…) |
| `doc-sync` | À la demande après changements structurels | Divergences code ↔ doc, patches proposés |
| `test-designer` | À la demande avant d'écrire des tests | Plan de tests priorisé (must / should / nice) |

---

## Hooks

| Hook | Événement | Rôle |
|---|---|---|
| `context-injector.sh` | `UserPromptSubmit` | Injecte workflow + état git à chaque prompt |
| `gitflow-guard.sh` | `PreToolUse:Bash` | Bloque commit direct main/develop, vérifie branche source feature/hotfix, bloque push --force |
| `danger-guard.sh` | `PreToolUse:Bash` | Bloque `rm -rf`, `terraform apply/destroy`, `kubectl delete`, `DROP TABLE`, `--no-verify` |
| `terraform-autofmt.sh` | `PostToolUse:Edit\|Write` | Format auto `*.tf` / `*.tfvars` |

---

## Scripts `bin/`

### `claude-init-project.sh`

Bootstrap un projet (init git, templates, GitFlow, pre-commit).

```bash
~/.claude/bin/claude-init-project.sh [options]
  -h, --help                          Aide
  -f, --force                         Écrase sans confirmer
  --no-git-flow                       Ne pas initialiser develop
  --no-pre-commit                     Ne pas poser les hooks pre-commit
  --install-prereqs                   Installe aussi les outils (tout)
  --install-prereqs-interactive       Installe en choisissant les groupes
```

### `claude-install-prereqs.sh`

Installe / met à jour les outils prérequis.

```bash
~/.claude/bin/claude-install-prereqs.sh [options]
  --all              Installe tous les groupes (défaut)
  --interactive      Choix à la carte par groupe
  --groups LISTE     Groupes spécifiques (virgules)
  --check            Audit seul, pas d'installation
  --dry-run          Simule
  --upgrade          Force la mise à jour
  --no-sudo          User-space uniquement (skip apt)

Groupes : core, secrets, python, terraform, docker, ansible, sql
```

### `install.sh` (à la racine du framework)

Setup des symlinks `~/.claude/` → framework (à lancer une fois sur nouvelle machine).

```bash
cd /datadisk/Inetum/claude-framework
./install.sh [--dry-run] [--force]
```

---

## Templates (`templates/`)

| Fichier | Rôle |
|---|---|
| `.editorconfig` | Indent, EOL, charset universels |
| `.gitignore` | Exclusions standards (OS, IDE, langages, Claude) |
| `.pre-commit-config.yaml` | Hooks multi-langages (terraform/tfsec/checkov, prettier, eslint, php-cs-fixer, phpstan, sqlfluff, hadolint, shellcheck, gitleaks, detect-secrets…) |
| `.yamllint` | Config yamllint stricte |
| `CLAUDE.md.template` | Template `CLAUDE.md` projet (à remplir) |

---

## Outils installés par `claude-install-prereqs.sh`

### Groupe `core` (toujours requis)
| Outil | Source | Rôle |
|---|---|---|
| `jq` | apt | JSON processing |
| `shellcheck` | apt | Linter shell |
| `shfmt` | GitHub | Formatter shell |
| `yamllint` | apt | Linter YAML |
| `git-flow` | apt | CLI GitFlow |
| `curl`, `unzip`, `file` | apt | Utilitaires |
| `pipx` | apt | Isolation Python packages |
| `pre-commit` | pipx | Gestionnaire de hooks pre-commit |

### Groupe `secrets`
| Outil | Source | Rôle |
|---|---|---|
| `gitleaks` | GitHub | Scan secrets dans git |
| `detect-secrets` | pipx | Baseline secrets + scan |

### Groupe `python`
| Outil | Source | Rôle |
|---|---|---|
| `ruff` | pipx | Lint + format Python ultra-rapide |
| `mypy` | pipx | Type checker |
| `black` | pipx | Formatter (alternative à ruff format) |

### Groupe `terraform`
| Outil | Source | Rôle |
|---|---|---|
| `terraform` | HashiCorp apt repo | Terraform CLI |
| `tflint` | GitHub | Linter HCL |
| `tfsec` | GitHub | Security scanner IaC |
| `checkov` | pipx | Policy-as-code pour IaC |

### Groupe `docker`
| Outil | Source | Rôle |
|---|---|---|
| `hadolint` | GitHub | Linter Dockerfile |

### Groupe `ansible`
| Outil | Source | Rôle |
|---|---|---|
| `ansible-lint` | pipx | Linter production-grade Ansible |

### Groupe `sql`
| Outil | Source | Rôle |
|---|---|---|
| `sqlfluff` | pipx | Linter/formatter SQL multi-dialect |

---

## Fichiers globaux

### `~/.claude/CLAUDE.md` → `framework/CLAUDE.md`
Instructions Claude globales : workflow, sécurité, GitFlow, style de réponse, pointeurs vers skills.

### `~/.claude/GITFLOW.md` → `framework/GITFLOW.md`
Workflow GitFlow détaillé (branches, tags, cycles feature/release/hotfix).

### `~/.claude/CODING_STANDARDS.md` → `framework/CODING_STANDARDS.md`
Normes de code par langage : Terraform, Ansible, Python, JS/TS, PHP, SQL, NoSQL, Docker, Bash, Markdown.

### `~/.claude/settings.json` → `framework/settings.json`
Permissions Claude Code (allowlist/denylist) + déclaration des hooks.

---

## Auto-memory (par projet)

Emplacement : `~/.claude/projects/<hash>/memory/`

| Fichier | Type | Contenu |
|---|---|---|
| `MEMORY.md` | Index | Liste des memories avec hook d'une ligne |
| `user_profile.md` | user | Rôle, préférences collaboration |
| `feedback_*.md` | feedback | Corrections/validations durables |
| `project_*.md` | project | État, décisions, contraintes du projet |
| `reference_*.md` | reference | Pointeurs vers systèmes externes (Jira, Grafana…) |

### Commandes
- Sauvegarder : `/save-context` (Claude le fait aussi automatique­ment)
- Recharger : `/load-context` (ou automatique au début de session)

---

## Fichiers / dossiers runtime (non versionnés)

Dans `~/.claude/` (pas dans le framework) :

| Item | Usage |
|---|---|
| `projects/` | Mémoire privée par projet |
| `sessions/` | Sessions Claude Code en cours |
| `history.jsonl` | Historique de tous les prompts |
| `cache/`, `downloads/`, `file-history/` | Runtime Claude |
| `paste-cache/`, `plans/`, `telemetry/` | Runtime Claude |
| `shell-snapshots/`, `session-env/`, `tasks/` | Runtime Claude |
| `plugins/` | Géré par Claude Code |
| `.credentials.json` | Auth tokens |

---

## Prochaines lectures

- **Comment faire X en pratique** → [07 Cookbook](07-cookbook.md)
- **Revenir au début** → [01 Overview](01-overview.md)
