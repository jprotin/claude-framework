# claude-framework

Framework personnel pour Claude Code : skills, sous-agents, hooks, scripts de bootstrap et normes de développement.

Conçu pour être **réutilisable sur tous les projets** via symlinks depuis `~/.claude/`.

---

## Structure

```
claude-framework/
├── CLAUDE.md                   # Instructions globales Claude (workflow, sécurité, règles transverses)
├── GITFLOW.md                  # Workflow GitFlow standardisé (cheatsheet danielkummer)
├── CODING_STANDARDS.md         # Normes de code par langage
├── settings.json               # Config Claude Code (permissions, hooks)
├── skills/                     # Compétences activables à la demande (25 skills)
│   ├── architect/              # Solution Architect
│   ├── sre/                    # Site Reliability Engineer
│   ├── devops/                 # DevOps / Platform
│   ├── security/               # Security Engineer
│   ├── dba/                    # Database Administrator
│   ├── terraform/              # Expert Terraform
│   ├── ansible/                # Expert Ansible
│   ├── kubernetes/             # Expert K8s
│   ├── docker/                 # Expert Docker
│   ├── linux/                  # Sysadmin Linux
│   ├── python/ bash/ javascript/ typescript/ php/
│   ├── analyze/ review/ debug/ commit/ gitflow/ adr/
│   ├── save-context/ load-context/ onboard-project/ skill-enrich/
├── agents/                     # Sous-agents spécialisés
│   ├── code-reviewer.md
│   ├── security-auditor.md
│   ├── doc-sync.md
│   └── test-designer.md
├── hooks/                      # Scripts shell pour automatisation Claude Code
│   ├── gitflow-guard.sh        # Bloque commits interdits par GitFlow
│   ├── danger-guard.sh         # Bloque opérations destructrices sans confirmation
│   ├── terraform-autofmt.sh    # Format auto *.tf après édition
│   └── context-injector.sh     # Injecte rappel workflow à chaque prompt
├── templates/                  # Templates à installer dans les projets
│   ├── .editorconfig
│   ├── .gitignore
│   ├── .pre-commit-config.yaml
│   ├── .yamllint
│   └── CLAUDE.md.template
└── bin/                        # Scripts d'installation / bootstrap
    ├── claude-init-project.sh      # Bootstrap d'un projet (fichiers config + git-flow + pre-commit)
    └── claude-install-prereqs.sh   # Installe/met à jour les outils (apt + pipx + GitHub binaries)
```

---

## Installation sur une nouvelle machine

### 1. Cloner le repo

```bash
git clone <url> /datadisk/Inetum/claude-framework
# ou n'importe où, ajuster ensuite
```

### 2. Lancer le script d'install

```bash
cd /datadisk/Inetum/claude-framework
./install.sh
```

Le script :
- Sauvegarde l'éventuel `~/.claude/` existant (dans `~/.claude.bak-YYYYMMDD/`)
- Crée les symlinks de `~/.claude/<item>` vers `<framework>/<item>` pour :
  `CLAUDE.md`, `GITFLOW.md`, `CODING_STANDARDS.md`, `settings.json`, `skills/`, `agents/`, `hooks/`, `templates/`, `bin/`
- Crée les dossiers runtime locaux si absents : `projects/`, `sessions/`, etc. (géré par Claude Code)

### 3. Installer les outils prérequis

```bash
~/.claude/bin/claude-install-prereqs.sh --check     # audit
~/.claude/bin/claude-install-prereqs.sh             # installer tout
```

---

## Utilisation

### Workflow transverse (automatique)

Sur toute demande non triviale, Claude applique :
**Analyse → Explication → Plan → Attente du Go** (jamais d'action avant validation).

Appliqué via `CLAUDE.md` global + hook `context-injector.sh` qui rappelle la règle à chaque prompt.

### GitFlow strict (automatique)

Les hooks `gitflow-guard.sh` et `danger-guard.sh` empêchent :
- Commit direct sur `main` / `develop`
- Création de `feature/*` hors de `develop`
- Création de `hotfix/*` hors de `main`
- `git push --force` sur branches protégées
- `rm -rf`, `terraform apply/destroy`, `kubectl delete`, `DROP TABLE`, `--no-verify` sans confirmation

### Skills à la demande

Tape dans Claude Code :

```
/architect              # endosse rôle Solution Architect
/terraform              # expert Terraform
/debug                  # méthode structurée de debug
/review                 # revue pré-livraison
/commit                 # aide à formuler un message de commit
/onboard-project        # bootstrap ce projet avec les standards
/load-context           # recharge contexte après reboot/gap
/save-context           # snapshot contexte en auto-memory
/adr                    # génère un Architecture Decision Record
...
```

Liste complète : voir `skills/` (25 skills).

### Sous-agents

Utilisés automatiquement par Claude ou sur demande :
- `code-reviewer` — revue indépendante avant commit
- `security-auditor` — audit sécurité
- `doc-sync` — cohérence code ↔ doc
- `test-designer` — stratégie de tests

---

## Bootstrap d'un nouveau projet

```bash
cd /chemin/vers/nouveau-projet
~/.claude/bin/claude-init-project.sh
```

Installe dans le projet : `.editorconfig`, `.pre-commit-config.yaml`, `.yamllint`, `.gitignore`, `CLAUDE.md` projet (gitignored), structure `docs/adr/` + `docs/runbooks/`, init `develop`, hooks pre-commit.

Options utiles :
- `--install-prereqs` : installe aussi tous les outils requis
- `--install-prereqs-interactive` : choix à la carte par groupe
- `--force` : écrase les fichiers existants
- `--no-git-flow` : skip init GitFlow

---

## Philosophie

- **Framework personnel, versionné** : chaque évolution est un commit
- **Réutilisable** : même framework sur toutes les machines et tous les projets
- **Transparent pour Claude Code** : via symlinks dans `~/.claude/`
- **Normes de code et workflow enforcés** : via hooks Claude + pre-commit côté projet
- **Compétences à la demande** : skills + sous-agents pour endosser des rôles d'expert

---

## Arborescence runtime (`~/.claude/`, non versionnée)

Gérée par Claude Code, **ne jamais ajouter au framework** :

- `projects/` — mémoire privée par projet
- `sessions/` — sessions en cours
- `history.jsonl` — historique des prompts
- `cache/`, `downloads/`, `file-history/`, `paste-cache/`, `plans/`, `shell-snapshots/`, `telemetry/`, `session-env/`, `tasks/`
- `plugins/` — géré par Claude Code
- `.credentials.json`, `mcp-needs-auth-cache.json`

---

## Évolution

Pour enrichir le framework :

1. Travailler directement dans `/datadisk/Inetum/claude-framework/` (les symlinks reflètent instantanément)
2. Un skill s'enrichit via `/skill-enrich <nom>` (ajout en section `## Learnings`)
3. Commit les changements (workflow GitFlow au choix, ou simple `main`)
4. Sur une autre machine : `git pull` suffit

---

## Licence

Framework personnel. Usage libre.
