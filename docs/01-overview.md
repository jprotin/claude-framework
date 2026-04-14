# 01 — Vue d'ensemble

> **Navigation :** [Accueil](../README.md) · [02 Architecture →](02-architecture.md) · [03 Mécanismes](03-mechanisms.md) · [04 Workflow](04-workflow.md) · [05 Cas d'usage](05-use-cases.md) · [06 Référence](06-reference.md) · [07 Cookbook](07-cookbook.md)

---

## À quoi ça sert ?

`claude-framework` est un **framework personnel** pour Claude Code qui industrialise l'expérience de développement, du premier commit à la livraison. Il t'apporte :

1. **Un workflow discipliné, automatique** : toute demande non triviale passe par Analyse → Explication → Plan → Attente du Go. Claude ne part pas en vrille avec une implémentation non validée.
2. **Des compétences expertes à la demande** : 25 skills qui font endosser à Claude le rôle d'architecte, de SRE, de DevOps, d'expert Terraform/Ansible/K8s/PHP/etc. sur simple invocation (`/architect`, `/terraform`…).
3. **Des sous-agents indépendants** : revue de code, audit sécurité, vérification doc, design de tests — chacun donne un avis non contaminé par le contexte de la conversation principale.
4. **Du GitFlow enforced** : les hooks Claude bloquent automatiquement les commits directs sur `main`/`develop`, les créations de branches hors source, les `push --force` risqués.
5. **Des normes de code enforced** : via `pre-commit` (Terraform, JS/TS, PHP, SQL, Docker, bash, etc.), scan de secrets (`gitleaks`, `detect-secrets`), scan IaC (`tfsec`, `checkov`).
6. **De la mémoire persistante entre sessions** : Claude mémorise automatiquement les décisions, préférences, contraintes projet — tu n'as pas à répéter.
7. **Un bootstrap un-clic** : `claude-init-project.sh` pour n'importe quel nouveau repo.

---

## Philosophie

### Ce qu'on veut éviter
- Claude qui se lance dans l'implémentation sans validation
- Avoir à re-préciser les mêmes préférences à chaque session
- Du code qui passe en review sans format ni lint ni scan sécurité
- Commits accidentels sur `main`, push --force destructeurs
- Perte de contexte après un reboot ou un gap de plusieurs jours
- Duplication de normes entre projets (chacun réinvente sa roue)

### Ce qu'on vise
- **Prévisibilité** : le comportement de Claude est stable et documenté
- **Réutilisabilité** : même framework sur tous les projets, toutes les machines
- **Auditabilité** : chaque évolution du framework = un commit git
- **Sécurité par défaut** : il faut explicitement demander pour faire quelque chose de risqué
- **Compétences à la demande** : de l'architecte au dev PHP, tout est accessible

---

## Pour qui ?

- **Solo developers / freelances** qui veulent un environnement de travail homogène sur tous leurs projets
- **Architectes / DevOps** qui changent régulièrement de stack et ont besoin d'un assistant qui endosse les bons rôles
- **Quiconque** veut que Claude Code soit un collègue discipliné, pas un stagiaire impulsif

---

## Ce qui a été créé

### Au global (repo `claude-framework`)

| Item | Nombre | Rôle |
|---|---|---|
| Documents fondateurs | 3 | `CLAUDE.md` (workflow), `GITFLOW.md`, `CODING_STANDARDS.md` |
| Skills | 25 | Compétences activables (5 métiers + 10 technos + 10 processus) |
| Sous-agents | 4 | Reviews indépendantes (code, sécurité, doc, tests) |
| Hooks | 4 | Garde-fous automatiques (GitFlow, destructifs, format TF, rappel workflow) |
| Templates | 5 | Fichiers prêts à poser dans un projet (editorconfig, pre-commit, gitignore, yamllint, CLAUDE.md) |
| Scripts bin/ | 2 | `claude-init-project.sh` (bootstrap), `claude-install-prereqs.sh` (outils) |
| `install.sh` | 1 | Setup des symlinks sur nouvelle machine |

### Par projet (quand tu bootstrapes avec `claude-init-project.sh`)

- `.editorconfig`, `.pre-commit-config.yaml`, `.yamllint`, `.gitignore` (versionnés, utiles à l'équipe)
- `CLAUDE.md` projet spécifique (**gitignored** — contexte projet privé)
- `docs/adr/`, `docs/runbooks/` (versionnés)
- Init git + GitFlow (`main` + `develop`)
- Hooks `pre-commit` installés

---

## Flux rapide : ce qui se passe quand tu bosses

1. Tu démarres une session Claude Code sur un projet
2. Le hook `context-injector.sh` **injecte un rappel** à chaque prompt :
   - Workflow analyse → plan → Go
   - Jamais de push/commit sans Go
   - GitFlow strict
   - État git courant (branche, modifié, ahead/behind)
3. Si tu tapes une demande non triviale, Claude applique **le workflow méta**
4. Tu valides, Claude exécute
5. Si Claude veut faire quelque chose de risqué (commit sur `main`, `rm -rf`, `terraform apply`) → les hooks `gitflow-guard.sh` / `danger-guard.sh` **bloquent** ou demandent confirmation
6. Après édition d'un `.tf`, le hook `terraform-autofmt.sh` **formate automatique­ment**
7. Si tu valides une décision ou une préférence → Claude la **mémorise automatique­ment** pour la prochaine session

Le détail de tout ça est dans [05 Cas d'usage](05-use-cases.md) avec des exemples concrets de bout en bout.

---

## Prochaines lectures

- **Comprendre comment c'est construit** → [02 Architecture](02-architecture.md)
- **Comprendre comment ça marche** → [03 Mécanismes](03-mechanisms.md)
- **Voir des exemples concrets** → [05 Cas d'usage](05-use-cases.md)
- **Chercher la commande / skill qu'il me faut** → [06 Référence](06-reference.md)
- **Recettes pratiques** → [07 Cookbook](07-cookbook.md)
