# 05 — Cas d'usage end-to-end

> **Navigation :** [← 04 Workflow](04-workflow.md) · [06 Référence →](06-reference.md) · [Accueil](../README.md)

7 scénarios concrets qui montrent comment **une demande traverse tout le système** — de ton prompt au résultat, en passant par hooks, skills, agents, et memory.

---

## Cas 1 : Bootstrap d'un nouveau projet

### Situation
Tu crées un nouveau dépôt pour une API REST en Python.

### Déclencheur
```bash
mkdir /datadisk/Inetum/mon-api
cd /datadisk/Inetum/mon-api
~/.claude/bin/claude-init-project.sh
```

### Ce qui se passe sous le capot

1. **Détection** : le script voit un dossier vide, pas de `.git`
2. **Git init** : crée le repo, branche `main`, commit vide initial
3. **Installation templates** :
   - `.editorconfig` copié depuis `~/.claude/templates/` → versionné
   - `.pre-commit-config.yaml` copié → versionné
   - `.yamllint` copié → versionné
   - `.gitignore` copié + injection automatique de `CLAUDE.md` et `.claude/` en tête
4. **Création `CLAUDE.md` projet** depuis le template → **gitignored**
5. **Structure docs** : `docs/adr/.gitkeep`, `docs/runbooks/.gitkeep`
6. **GitFlow init** : création de la branche `develop` depuis `main`
7. **Pre-commit install** : hooks posés dans `.git/hooks/`
8. **Audit prérequis** : liste les outils manquants, propose `claude-install-prereqs.sh`

### Tu fais ensuite
```bash
# Compléter CLAUDE.md (privé) avec ta stack Python
vim CLAUDE.md
# → description : "API REST Python 3.12 + FastAPI + Postgres"

# Créer la structure Python
mkdir -p src/myapi tests
touch src/myapi/__init__.py pyproject.toml

# Installer les prérequis si manquants
~/.claude/bin/claude-install-prereqs.sh --groups core,python,secrets

# Valider
pre-commit run --all-files
```

### Résultat
- Repo propre avec normes enforced
- `main` + `develop` prêtes
- Claude aura le contexte projet à chaque session (via `CLAUDE.md`)
- Pre-commit bloquera tout commit mal formaté

---

## Cas 2 : Nouvelle feature (workflow GitFlow complet)

### Situation
Tu veux ajouter un endpoint `/users` à ton API.

### Déclencheur
Tu dis à Claude : « Ajoute un endpoint GET /users qui retourne la liste paginée des utilisateurs. »

### Ce qui se passe

**Phase 1 — workflow méta (Claude raisonne avant d'agir)**
- Hook `context-injector.sh` rappelle les règles
- Claude lit `CLAUDE.md` projet : voit que c'est FastAPI + Postgres
- Claude applique le workflow :
  - Analyse (quelles colonnes retourner ? pagination cursor ou offset ?)
  - Options (Pydantic response models vs dict, SQLAlchemy Core vs ORM)
  - Plan (créer model, schema, router, test, migration)
  - **Attente Go**

**Phase 2 — Tu valides. Claude commence.**
- Claude veut faire `git checkout -b feature/users-endpoint`
- Hook `gitflow-guard.sh` : vérifie branche courante
  - Si `develop` → OK, création autorisée
  - Si autre → **bloqué** avec message « Crée depuis `develop` »
- Claude fait alors `git checkout develop && git pull` puis retente

**Phase 3 — Claude écrit le code**
- Édite `src/myapi/routes/users.py`, `schemas/users.py`, etc.
- Écrit les tests dans `tests/test_users.py`
- Hook `PostToolUse` ne se déclenche pas (pas de `.tf`)

**Phase 4 — Revue indépendante**
- Claude invoque proactivement le sous-agent `code-reviewer`
- L'agent ne voit PAS le raisonnement de Claude → avis objectif
- Retourne : 1 bloquant (manque validation email), 2 recommandations (nommage var)
- Claude corrige avant de proposer le commit

**Phase 5 — Commit**
- Invoque `/commit` : analyse `git diff --staged`, propose un message
- Tu valides : `git commit -m "Ajoute endpoint GET /users avec pagination"`
- Hook `gitflow-guard.sh` : vérifie qu'on n'est pas sur `main`/`develop` → OK (on est sur `feature/users-endpoint`)
- Hook `danger-guard.sh` : pas de `--no-verify` → OK
- `pre-commit` tourne (hook git natif) : ruff + mypy + gitleaks + secrets → OK
- Commit validé

**Phase 6 — Merge dans develop**
- Tu dis « Merge la feature »
- Claude fait `git checkout develop && git pull && git merge --no-ff feature/users-endpoint`
- Hook `gitflow-guard.sh` : merge OK (pas un commit direct, c'est un merge)
- Delete branche locale
- **Push demande ton Go explicite** (règle de sécurité)

### Résultat
- Code livré, reviewé, formaté, testé
- Historique git propre avec merge `--no-ff`
- Aucune règle contournée

---

## Cas 3 : Hotfix urgent en prod

### Situation
Un bug critique est détecté en prod (version v1.2.0) : les utilisateurs ne peuvent plus se connecter.

### Déclencheur
Tu dis : « Fais un hotfix urgent : le champ `email` du login est buggé en prod. »

### Ce qui se passe

**Phase 1 — analyse rapide**
- Claude applique le workflow méta (reste obligatoire même en urgence)
- Analyse : bug localisé dans `src/myapi/auth.py:42` (lowercase manquant)
- Plan : hotfix depuis `main`, fix, tests, double merge, tag

**Phase 2 — Go. Claude lance le workflow hotfix**
- `git checkout main && git pull`
- `git checkout -b hotfix/email-login`
- Hook `gitflow-guard.sh` : vérifie branche source = `main` → OK

**Phase 3 — Fix + test**
- Édite `auth.py` : ajoute `.lower()` sur l'email
- Ajoute un test de non-régression
- Bump version `1.2.0 → 1.2.1` dans `pyproject.toml`

**Phase 4 — Commit**
- `/commit` → message clair
- Commit OK

**Phase 5 — Double merge + tag (le point critique)**
- Claude sait (via le skill `/gitflow`) qu'un hotfix nécessite un **double merge**
- Tu dis « finalise »
- Claude propose :
  ```bash
  git checkout main
  git merge --no-ff hotfix/email-login
  git tag -a v1.2.1 -m "Hotfix 1.2.1 - email lowercase"
  git checkout develop && git pull
  git merge --no-ff hotfix/email-login
  git branch -d hotfix/email-login
  ```
- Hook `gitflow-guard.sh` : sur chaque merge `release/*` ou `hotfix/*`, rappelle le double merge (garde-fou)
- **Push attend ton Go explicite**

**Phase 6 — Mémoire**
- Claude détecte que c'était une régression « email non normalisé » → sauvegarde en `project_auth_lessons.md` pour éviter la répétition

### Résultat
- `main` a la v1.2.1 taguée, prête à déployer
- `develop` a reçu le fix (pas de régression au prochain merge)
- Runbook à jour dans la memory

---

## Cas 4 : Reprise après reboot / long gap

### Situation
Tu reprends le projet après 2 semaines de congés. Tu as tout oublié.

### Déclencheur
Dans Claude Code, tu tapes : `/load-context`

### Ce qui se passe

1. Claude identifie le projet (working directory)
2. Lit `CLAUDE.md` projet (stack, contraintes, décisions clés)
3. Lit `MEMORY.md` + toutes les memories `project_*`
4. Lit `README.md`, ADR récents dans `docs/adr/`, `CHANGELOG.md`
5. Exécute `git status`, `git log --oneline -15`, `git branch`, `git diff --stat`
6. Synthétise :

```
## Reprise de contexte — mon-api

### Statut projet
- Objectif : API REST utilisateurs (FastAPI + Postgres)
- Stack : Python 3.12, FastAPI 0.110, SQLAlchemy 2.0
- Branche courante : feature/permissions
- Dernière activité : 2026-03-30 "Ajoute role-based access"

### Travail en cours (non commité)
- src/myapi/routes/permissions.py (42 lignes ajoutées)
- tests/test_permissions.py (nouveau)

### Décisions récentes
- ADR-0003 : choix de pgcrypto pour hash passwords
- ADR-0004 : migration vers Pydantic v2

### Ce qui semble en attente
Tu étais en train d'ajouter les permissions (feature/permissions).
Le code est en place mais les tests ne couvrent pas les edge cases.

### Prochaine étape suggérée
Finir les tests permissions → commit → merge dans develop.
```

### Résultat
En 30 secondes tu es à nouveau dans le contexte. Sans relire le code.

---

## Cas 5 : Décision d'architecture avec ADR

### Situation
Tu dois choisir entre Redis et Postgres LISTEN/NOTIFY pour un système de messages temps réel.

### Déclencheur
Tu dis : « Aide-moi à choisir entre Redis Streams et PG LISTEN/NOTIFY pour notifications temps réel. »

### Ce qui se passe

**Phase 1 — `/architect` s'active**
Claude détecte (via la description du skill) que c'est une question architecturale → propose d'endosser le rôle.

**Phase 2 — Claude applique la méthode `/architect`**

```
## Reformulation du besoin
Système de notifications push temps réel vers clients web (< 500 ms de latence).
Volume : ~100 notifs/s à moyen terme, bursts à 2000/s.

## Contraintes identifiées
- Stack existante : Postgres 16, pas de Redis pour l'instant
- Contrainte perf : P99 < 500 ms
- Équipe : 1 dev, familiarité SQL forte, zéro expérience Redis

## Options

### Option A : Postgres LISTEN/NOTIFY
+ Zéro nouvelle dépendance
+ Transactionnel avec le reste des données
+ Équipe connaît déjà PG
- Limite payload 8kB
- Pas de buffering si le consumer déconnecte
- Difficile à scaler horizontalement (connexion unique au master)

### Option B : Redis Streams
+ Conçu pour ça, scalabilité prouvée
+ Buffering + consumer groups natifs
- Nouvelle techno à opérer (backups, HA, monitoring)
- Désync potentielle avec data Postgres

### Option C : NATS / Kafka
- Overkill pour le volume annoncé

## Recommandation
Option A (LISTEN/NOTIFY) en phase 1. Passer à B si :
- Volume dépasse 500/s soutenu
- Besoin de replay / persistence messages
- Besoin de plusieurs consumers groups

## Plan de sortie
Si migration nécessaire : wrapper applicatif abstrait le transport
(interface `Notifier` avec 2 impls) → swap en une journée.
```

**Phase 3 — Tu valides Option A**
Claude propose d'acter ça en ADR.

**Phase 4 — Skill `/adr` génère le doc**
```
Claude cherche le prochain numéro : ls docs/adr/
Dernier = 0002 → génère 0003-notifications-temps-reel.md
Template rempli, ouvre l'éditeur ou te montre le contenu
```

Le fichier est créé, pas commité — tu valides le contenu d'abord.

### Résultat
- Décision tracée, argumentée, avec option de sortie
- Futur-toi dans 6 mois comprendra POURQUOI ce choix
- Futur-équipe (si tu en embauches) a le contexte

---

## Cas 6 : Session de debug structurée

### Situation
En staging, les uploads d'images > 2 Mo échouent silencieusement 1 fois sur 5.

### Déclencheur
Tu dis : « Débug : les uploads > 2Mo échouent en silence sur staging, 1 fois sur 5. »

### Ce qui se passe

**Phase 1 — `/debug` s'active**
Claude adopte la méthode structurée.

**Phase 2 — 6 étapes rigoureuses**

```
### 1. Reproduire
Peux-tu me donner :
- Un fichier qui échoue reproductible ?
- La commande / URL exacte utilisée ?
- Logs exacts (stdout + stderr) ?

### 2. Caractériser
[tu fournis les infos]
Symptôme : POST /upload 500 Internal
Attendu : 200 + URL de l'image uploadée
Depuis : apparu après déploiement v1.1.8
Partiel : 1/5 des uploads > 2Mo
Impact : staging only, bloquant pour QA

### 3. Isoler
Claude propose :
- git bisect entre v1.1.7 (OK) et v1.1.8 (KO)
- Regarder les logs nginx (peut être timeout upstream)
- Regarder si ça arrive toujours ou dépend du ratio compression
```

**Phase 3 — Claude investigue**
- Lit les logs
- Remarque : timeout nginx à 30s, uploads 2Mo sur lien lent → pile 30s
- Confirme en reproduisant à 2.5 Mo sur connexion throttlée

**Phase 4 — Hypothèse + test**
Hypothèse : nginx a un timeout `proxy_read_timeout 30s` par défaut, les gros uploads le dépassent.

Test : incréaase `client_max_body_size + proxy_read_timeout 60s` en staging → plus d'échec.

**Phase 5 — Fix à la cause racine**
- **Symptôme masqué** : retry applicatif qui réessaie 5×
- **Cause racine** : nginx timeout sous-dimensionné
- **Vrai fix** : config nginx + monitoring sur timeouts nginx (pour détecter avant que QA s'en plaigne)

**Phase 6 — Non-régression**
- Commit avec test e2e qui upload 3 Mo
- Alerte Grafana sur `nginx.upstream.response_time > 20s`
- Runbook « si upload fail → check nginx logs 500 proxy_read_timeout »

### Résultat
- Bug réglé à la cause, pas au symptôme
- Monitoring préventif en place
- Runbook pour futur incident similaire

---

## Cas 7 : Audit sécurité avant release

### Situation
Tu t'apprêtes à cutter la v2.0 d'une app e-commerce. Tu veux t'assurer qu'aucune vulnérabilité flagrante ne passe.

### Déclencheur
Tu dis : « Audit sécurité complet avant release v2.0. »

### Ce qui se passe

**Phase 1 — Sous-agent `security-auditor` invoqué**
Claude lance l'agent en isolation (pas de contamination du contexte principal).

**Phase 2 — L'agent scanne automatiquement**

```bash
gitleaks detect --no-banner --redact
detect-secrets scan
tfsec .
checkov -d .
hadolint Dockerfile
npm audit
```

**Phase 3 — Revue manuelle checklist**
L'agent parcourt :
- Secrets / creds hardcodés
- Input validation (SQL injection, XSS, SSRF)
- Auth (hashing, sessions, JWT)
- Authz sur tous les endpoints sensibles
- Crypto (TLS, randomness)
- Headers HTTP (CSP, HSTS)
- Logs sans PII
- IAM / deps / supply chain
- Surface d'attaque

**Phase 4 — Rapport structuré**

```
# Security Audit Report

## Scope
Repo e-commerce, versions v1.x → v2.0 (diff)

## Synthèse
2 critiques, 5 importants, 3 observations

## Critiques (à fixer IMMÉDIATEMENT)

1. **Injection SQL** — `src/products/search.py:87`
   Menace : attaquant peut lister toutes les tables via `q=' UNION ...`
   Preuve : `cursor.execute(f"SELECT ... WHERE name LIKE '%{q}%'")`
   Fix : utiliser requête paramétrée `cursor.execute("... LIKE %s", (f"%{q}%",))`

2. **JWT sans validation expiration** — `src/auth/middleware.py:34`
   Menace : tokens volés restent valides à vie
   Preuve : `jwt.decode(token, SECRET, algorithms=["HS256"])` sans `require=["exp"]`
   Fix : ajouter `options={"require": ["exp", "iss", "aud"]}`

## Importants
...

## Verdict
❌ 2 vulnérabilités exploitables directement — bloquer la release.
```

**Phase 5 — Claude te présente le rapport**
Pas de fix automatique — l'agent **ne modifie pas le code**, il reporte.

**Phase 6 — Tu corriges, puis Claude relance l'audit**
Nouveau rapport → ✅ plus de critique → release débloquée.

### Résultat
- Tu as la certitude que les 10 OWASP top 10 sont regardés
- Tu as des fix précis, pas juste « vérifie ta sécurité »
- L'audit est **indépendant** de ce que Claude a écrit pendant la session

---

## Ce que ces cas montrent

| Mécanisme | Cas où il intervient |
|---|---|
| Workflow méta | Tous (chaque demande non triviale) |
| Hook `context-injector` | Tous (chaque prompt) |
| Hook `gitflow-guard` | Cas 2, 3 (opérations git) |
| Hook `danger-guard` | Cas 2, 3, 7 (opérations risquées) |
| Hook `terraform-autofmt` | Si édition .tf (pas dans ces exemples Python) |
| Skill `/architect` | Cas 5 |
| Skill `/debug` | Cas 6 |
| Skill `/gitflow` | Cas 3 |
| Skill `/commit` | Cas 2, 3 |
| Skill `/adr` | Cas 5 |
| Skill `/load-context` | Cas 4 |
| Sous-agent `code-reviewer` | Cas 2 |
| Sous-agent `security-auditor` | Cas 7 |
| Auto-memory | Cas 2, 3, 4 (sauvegarde lessons learned) |
| `claude-init-project.sh` | Cas 1 |
| `pre-commit` | Cas 1, 2 (format, lint, secrets) |

Chaque mécanisme a son rôle précis. Tous ensemble, ils forment un système qui **amplifie ton travail sans t'infantiliser**.

---

## Prochaines lectures

- **Liste complète des skills/agents/scripts** → [06 Référence](06-reference.md)
- **Recettes pratiques** → [07 Cookbook](07-cookbook.md)
