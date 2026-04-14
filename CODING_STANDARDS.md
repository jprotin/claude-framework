# CODING_STANDARDS.md — Normes de code transverses

Standards appliqués sur **tous les projets**. Enforcement automatique via `pre-commit` (voir `~/.claude/templates/.pre-commit-config.yaml`).

---

## Principes universels

- **Nommage explicite** — pas d'abréviations obscures, pas de `tmp`, `data`, `x` en variable longue durée
- **Fonctions courtes** — si > 50 lignes ou > 3 niveaux d'imbrication, refactorer
- **Pas de code mort** — code commenté supprimé, imports inutilisés supprimés
- **Commentaires** : pourquoi, pas quoi. Le code explique le quoi.
- **Tests** : tout nouveau code critique = au moins un test. Les tests existants restent verts.
- **Sécurité** : pas de secret hardcodé, validation des entrées externes, principe du moindre privilège

---

## Encodage universel

- UTF-8, LF (pas CRLF), final newline, pas de trailing whitespace
- Indentation cohérente par langage (voir tableau ci-dessous)
- Enforced par `.editorconfig` + `pre-commit` (`end-of-file-fixer`, `trailing-whitespace`)

| Langage | Indent | Taille |
|---|---|---|
| Terraform, HCL | Espaces | 2 |
| YAML, JSON | Espaces | 2 |
| Markdown | Espaces | 2 |
| Python | Espaces | 4 |
| PHP | Espaces | 4 |
| JavaScript, TypeScript | Espaces | 2 |
| SQL | Espaces | 2 |
| Bash/SH | Espaces | 2 |
| Go | Tabs | - |
| Makefile | Tabs | - |

---

## Terraform / HCL

- **Naming** : `snake_case` pour ressources, variables, outputs, modules
- **Structure module** : `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`
- **Versions** : toujours pinner les providers (`~> 2.5`), jamais `>= 0`
- **State** : backend distant obligatoire (S3, Swift, Terraform Cloud), jamais local en équipe
- **Variables** : typées, description obligatoire, `sensitive = true` pour les secrets
- **Outputs** : description obligatoire, `sensitive = true` si nécessaire
- **Tags** : bloc `tags` ou `labels` standard (`environment`, `project`, `managed_by = "terraform"`)
- **Modules** : un module = une unité cohérente, pas de `for_each` sur plusieurs types de ressources
- **Formatage** : `terraform fmt` automatique
- **Validation** : `terraform validate` + `tflint` + `tfsec` + `checkov`

---

## Ansible

- **YAML 2 espaces**, `---` en début de fichier, pas de tabs
- **Structure role** : `tasks/`, `handlers/`, `defaults/`, `vars/`, `templates/`, `files/`, `meta/`
- **Idempotence** : chaque task doit être idempotente, vérifier avec `--check`
- **Naming** : tasks nommées en verbe infinitif (`"Install nginx package"`)
- **Secrets** : `ansible-vault` obligatoire, jamais de `password: xxx` en clair
- **FQCN** : utiliser les collections full-qualified (`ansible.builtin.copy`, pas `copy`)
- **Lint** : `ansible-lint` niveau production, `yamllint` strict

---

## Python

- **Version** : Python 3.10+ sauf contrainte
- **Formatage** : `black` (line-length 100)
- **Lint** : `ruff` (config stricte), `mypy` en strict mode
- **Type hints** : obligatoires sur fonctions publiques, recommandés ailleurs
- **Docstrings** : Google style ou NumPy style, cohérent sur le projet
- **Imports** : triés par `ruff`/`isort`, groupés (stdlib, third-party, local)
- **Packaging** : `pyproject.toml`, pas de `setup.py` legacy
- **Virtualenv** : `venv` ou `uv`, jamais en global
- **Tests** : `pytest`, coverage minimum 70%

---

## JavaScript / TypeScript

- **Version** : Node.js LTS actuelle, ES modules (`"type": "module"`)
- **TypeScript** : `strict: true`, `noUncheckedIndexedAccess: true`
- **Formatage** : `prettier` (défaut ou config équipe)
- **Lint** : `eslint` (`@typescript-eslint` en TS), config Airbnb ou Standard
- **Imports** : ordonnés, absolus > relatifs profonds (`@/…`)
- **Naming** : `camelCase` variables/fonctions, `PascalCase` classes/types, `SCREAMING_SNAKE` constantes
- **Async** : `async/await`, pas de callbacks, `.catch` ou `try/catch` explicite
- **Types** : préférer `type` à `interface` sauf extension, éviter `any`, préférer `unknown`
- **Package manager** : `pnpm` recommandé (rapide, strict), sinon `npm`
- **Tests** : `vitest` ou `jest`

---

## PHP

- **Version** : PHP 8.2+ sauf contrainte
- **Style** : **PSR-12**, enforced par `php-cs-fixer`
- **Analyse statique** : `phpstan` niveau 8 (max), ou `psalm` strict
- **Typage** : `declare(strict_types=1);` en tête de chaque fichier, types partout (params, retours, propriétés)
- **Naming** : `PascalCase` classes, `camelCase` méthodes/variables, `UPPER_SNAKE` constantes
- **PSR-4** autoload obligatoire via Composer
- **Pas de globales**, pas de `@` suppresseur d'erreur
- **Tests** : `phpunit` ou `pest`
- **Framework** : conventions du framework utilisé (Laravel, Symfony) prioritaires sur les règles ici si conflit

---

## SQL

- **Mots-clés** : MAJUSCULES (`SELECT`, `FROM`, `WHERE`, `JOIN`)
- **Identifiants** : `snake_case`, pluriels pour tables (`users`, `orders`)
- **Clés primaires** : `id` (sauf contrainte), `UUID` v7 ou `BIGINT` auto-incrément
- **Foreign keys** : `<table>_id` (ex: `user_id`)
- **Pas de `SELECT *`** en code applicatif (explicite les colonnes)
- **Index** : sur les FK, sur les colonnes de filtre fréquent
- **Migrations** : versionnées, réversibles, testées
- **Formatage** : `sqlfluff` (dialect adapté : postgres, mysql, bigquery…)

---

## NoSQL (MongoDB, Redis, etc.)

- **Schémas** : documenter même sans enforcement (JSON Schema pour MongoDB)
- **Indexation** : adaptée aux patterns de query, monitorée
- **Naming** : `camelCase` documents (MongoDB), `snake_case` ou `colon:separated` pour clés Redis
- **TTL** : expliciter sur les données temporaires (cache, sessions)
- **Backup** : stratégie documentée, testée

---

## Docker

- **Base images** : versionnées (`node:20.11-alpine`, jamais `node:latest`)
- **Multi-stage** obligatoire pour les builds applicatifs (builder / runtime)
- **Utilisateur non-root** : `USER app` après installation
- **COPY explicite** : pas de `COPY . .` sans `.dockerignore` rigoureux
- **Layer caching** : `COPY package.json .` → `RUN install` **avant** `COPY . .`
- **Healthcheck** : défini sur les services long-running
- **Lint** : `hadolint`
- **Secrets** : **jamais** en ARG/ENV. Utiliser build secrets ou runtime secrets.

---

## Bash / Shell

- **Shebang** : `#!/usr/bin/env bash` (portabilité) ou `#!/bin/sh` si strict POSIX
- **Strict mode** : `set -euo pipefail` en tête de tout script
- **Quoting** : `"$variable"` toujours, jamais `$variable` nu
- **`[[ ]]`** pour bash, `[ ]` pour sh POSIX
- **Fonctions** : `local` pour les variables internes
- **Paramètres** : `getopts` ou parsing explicite, messages d'usage
- **Lint** : `shellcheck` (0 warning) + `shfmt`
- **Logs** : fonction `log()` dédiée, pas de `echo` éparpillés

---

## Markdown

- **Structure** : `#` unique en tête de fichier, hiérarchie sans saut (`##` → `###`)
- **Lignes** : `markdownlint` (default rules, MD013 assoupli si besoin)
- **Liens** : relatifs pour intra-repo, absolus avec HTTPS pour externes
- **Code** : toujours en blocs avec langage (` ```bash `), pas en inline > 2 mots
- **Front-matter** : YAML `---` si attendu par le générateur (Hugo, Jekyll, skills)

---

## YAML / JSON

- **YAML** : 2 espaces, `---` en tête, `yamllint` strict
- **JSON** : 2 espaces, trailing newline, pas de commentaires (utiliser JSONC/JSON5 si besoin)
- **Schéma** : JSON Schema pour configs critiques

---

## Sécurité transverse

- **Secrets** : scan `gitleaks` + `detect-secrets` à chaque commit
- **Dépendances** : scan CVE (`npm audit`, `pip-audit`, `composer audit`, Dependabot)
- **IaC** : `tfsec`, `checkov`, `kube-score` selon le stack
- **Principe** : aucune clé, mot de passe, token en clair dans le repo. Même pour du dev.
- **.env** : dans `.gitignore`, `.env.example` versionné (sans valeurs)

---

## Documentation

- `README.md` racine : objectif, stack, install, usage, structure
- `CHANGELOG.md` : format [Keep a Changelog](https://keepachangelog.com/)
- `docs/` pour les guides longs, pas dans le README
- ADR dans `docs/adr/` (voir skill `/adr`)

---

## Revue avant delivery

Checklist minimale avant merge vers `develop` :

- [ ] `pre-commit run --all-files` vert
- [ ] Tests unitaires verts
- [ ] Pas de secret détecté
- [ ] `README.md` / doc à jour si comportement public changé
- [ ] Message(s) de commit clair(s)
- [ ] Diff revu (idéalement par sous-agent `code-reviewer` avant demande humaine)
