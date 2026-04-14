# 04 — Workflows (méta + GitFlow)

> **Navigation :** [← 03 Mécanismes](03-mechanisms.md) · [05 Cas d'usage →](05-use-cases.md) · [Accueil](../README.md)

---

## Workflow méta : Analyse → Explication → Plan → Go

### Applicable à
**Toute demande non triviale**. Claude ne peut pas y couper.

### Les 4 étapes

#### 1. Analyse
Claude comprend la demande avant d'agir :
- **Ma compréhension** — reformulation dans ses mots
- **Contexte pertinent** — fichiers / memory / git log qui influencent la réponse
- **Contraintes et risques** — techniques, sécurité, perf, effets de bord

#### 2. Explication
Claude énonce 2-3 options (sauf cas trivial) :
- Pour chaque option : le pour, le contre
- Recommandation argumentée + conditions d'application

#### 3. Plan d'action
Étapes concrètes numérotées, dans l'ordre. Pas de flou.

#### 4. Attente du Go
Claude **ne fait rien** (hors lectures / recherches / grep) tant que tu n'as pas validé.

### Exceptions (action directe autorisée)
- Lecture de fichiers, `grep`, `find`, `git log` (exploration)
- Questions factuelles ne modifiant rien
- Suite d'un plan déjà validé dans la conversation courante

### Exemple

```
Toi : « Refactore le module MKS pour séparer les inputs optionnels. »

Claude (workflow méta) :
  1. Ma compréhension
     Tu veux extraire les inputs optionnels du module MKS dans un sous-objet
     pour clarifier les usages avancés vs les défauts.

  2. Contexte
     - modules/mks/variables.tf : 23 variables, 8 optionnelles
     - Le module est utilisé par envs/mks-sandbox-par
     - Breaking change si on renomme → envs/* à adapter

  3. Options
     A - Sous-objet `advanced = { ... }` : clair mais changement d'API
     B - Rester en variables plates + préfixe `advanced_*` : moins intrusif
     C - Garder variables plates, documenter mieux via README

  4. Recommandation : A avec module-level variable + migration guide
     Conditions : OK si tu acceptes de mettre à jour les envs.

  5. Plan
     5.1 Créer variable `advanced` type object
     5.2 Déprécier les 8 variables optionnelles (warning)
     5.3 Mettre à jour envs/mks-sandbox-par
     5.4 Ajouter CHANGELOG
     5.5 Bump version du module

  En attente de ton Go.
```

### Pourquoi c'est indispensable
Sans ce workflow :
- Claude part dans l'implémentation avant d'avoir compris
- Tu découvres en lisant le diff que la solution n'est pas celle que tu voulais
- Retour en arrière coûteux (re-diff, re-commit, re-explication)

Avec ce workflow :
- Tu valides sur le papier en 30 secondes
- L'implémentation va droit au but
- Les options sont explicites (tu peux demander B au lieu de A sans frustration)

### Ce qui l'automatise
- `CLAUDE.md` global l'impose
- Hook `context-injector.sh` rappelle la règle à **chaque** prompt

---

## Workflow GitFlow

Conforme au cheatsheet **danielkummer.github.io/git-flow-cheatsheet/**.

### Branches permanentes

| Branche | Rôle | Règles |
|---|---|---|
| `main` | Image prod | Reçoit uniquement des merges depuis `release/*` ou `hotfix/*` + tag git `vX.Y.Z`. **Aucun commit direct.** |
| `develop` | Intégration | Reçoit merges depuis `feature/*`, `release/*`, `hotfix/*`. **Aucun commit direct.** |

### Branches temporaires

```
develop ─┬─────────────────────────────────────────┬──────────────────
         │                                         │
         └─→ feature/auth ──────→ merge -----------┘
         └─→ feature/api ────────────→ merge ------┘

         ┌─→ release/1.2.0 ──────→ merge ─→─── merge → main ──→ tag v1.2.0
         │
main ────┴───────────────────────────────────────────────────────────

main ────┬──→ hotfix/crit ──────→ merge ─→─── merge → main ──→ tag v1.2.1
         │                           │
         └─────────────────── merge to develop
```

### Cycle feature (le plus fréquent)

```bash
# 1. Partir d'un develop à jour
git checkout develop && git pull

# 2. Créer la feature
git checkout -b feature/ma-feature
# ou : git flow feature start ma-feature

# 3. ... commits ...

# 4. Finaliser (merge + delete + push)
git checkout develop && git pull
git merge --no-ff feature/ma-feature
git branch -d feature/ma-feature
git push origin develop
```

### Cycle release (mise en prod)

```bash
# 1. Créer depuis develop
git checkout develop && git pull
git checkout -b release/1.2.0

# 2. Bumper version, corrections mineures
# (édite VERSION / package.json / pyproject.toml)

# 3. Double merge + tag
# → main
git checkout main && git pull
git merge --no-ff release/1.2.0
git tag -a v1.2.0 -m "Release 1.2.0"
# → develop
git checkout develop
git merge --no-ff release/1.2.0

# 4. Cleanup + push
git branch -d release/1.2.0
git push origin main develop --tags
```

### Cycle hotfix (correctif urgent)

```bash
# 1. Partir de main
git checkout main && git pull
git checkout -b hotfix/correctif-crit

# 2. ... fix ... bump patch (1.2.0 → 1.2.1) ...

# 3. Double merge + tag
git checkout main
git merge --no-ff hotfix/correctif-crit
git tag -a v1.2.1 -m "Hotfix 1.2.1"
git checkout develop && git pull
git merge --no-ff hotfix/correctif-crit

# 4. Cleanup + push
git branch -d hotfix/correctif-crit
git push origin main develop --tags
```

### Ce qui l'automatise

- `GITFLOW.md` documente le workflow
- Hook `gitflow-guard.sh` bloque les violations (commit sur main/develop, branche source incorrecte)
- Skill `/gitflow` guide interactivement pas-à-pas
- `pre-commit` hook `no-commit-to-branch` = deuxième filet de sécurité

### Désactivation automatique du GitFlow

Le hook `gitflow-guard.sh` ne s'active **que si la branche `develop` existe** dans le repo. Pour un repo simple (main-only, GitHub Flow), les règles sont levées. Tu n'as pas à désactiver manuellement.

---

## Workflow commit — libre par défaut

### Règle
Format **libre** par défaut (pas de `feat(scope):` imposé).

### Skill `/commit` pour soigner le message
Invoque `/commit` quand tu veux que Claude :
- Analyse `git diff --staged`
- Te propose un message (libre ou Conventional Commits au choix)
- Commit après Go explicite

### Bonnes pratiques
- Impératif (« Ajoute », pas « Ajouté »)
- Sujet < 72 caractères, sans point final
- Corps optionnel : **pourquoi**, pas le **quoi** (le diff montre le quoi)
- Un commit = une unité logique (si 2 changes distincts, 2 commits)

---

## Workflow de reprise après gap/reboot

### Le skill `/load-context`

À lancer quand tu reprends un projet après un long gap ou un reboot :
1. Lit `CLAUDE.md` projet
2. Lit `MEMORY.md` + memories pertinentes
3. Lit `README.md`, ADR récents, CHANGELOG
4. Fait `git status`, `git log --oneline -15`, `git diff --stat`
5. Produit un **rapport synthétique** :
   - Objectif, stack, branche courante
   - Travail en cours (non committé)
   - Décisions récentes
   - Proposition d'étape suivante

### Le skill `/save-context`

À lancer avant un long break, ou quand une décision structurante vient d'être prise :
1. Identifie ce qui n'est **pas dérivable du code**
2. Sauvegarde en auto-memory (type approprié)
3. Confirme ce qui a été persisté

---

## Workflow d'enrichissement continu du framework

Quand tu découvres un pattern, piège, ou règle **durable** qu'un skill devrait connaître :

```
Tu tapes : /skill-enrich terraform
Claude :
  • Détecte le pattern appris pendant la session
  • Distille en règle actionnable (avec "Quand" et "Pourquoi")
  • Ajoute à ~/.claude/skills/terraform/SKILL.md section ## Learnings
  • Te montre le diff
  • Attend ton Go pour valider

Tu valides → commit sur claude-framework/main possible
```

Le skill s'améliore à chaque session, s'accumule avec le temps, devient de plus en plus précieux.

---

## Prochaines lectures

- **Voir tous ces workflows appliqués** → [05 Cas d'usage](05-use-cases.md)
- **Quelle commande pour faire X** → [06 Référence](06-reference.md)
