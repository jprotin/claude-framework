---
name: load-context
description: Re-synchronisation complète du contexte projet après un reboot, un long gap, ou changement de session. Charge memory + git + docs clés et produit un résumé actionnable. À invoquer quand on reprend un projet.
---

# Skill : Load Context

Re-charge et résume le contexte d'un projet pour reprendre efficacement le travail.

## Procédure

1. **Détecter le projet courant** (working directory)

2. **Charger les sources de vérité** (dans l'ordre) :
   - `CLAUDE.md` du projet (s'il existe)
   - `MEMORY.md` dans `~/.claude/projects/<hash>/memory/`
   - Tous les fichiers memory pertinents (surtout `project_*`)
   - `README.md`, `DOCUMENTATION.md` à la racine
   - `docs/adr/` les 3-5 plus récents
   - `CHANGELOG.md` (dernière section)

3. **État git actuel** :
   ```bash
   git status
   git log --oneline -15
   git diff --stat                      # travail en cours
   git branch --show-current
   git stash list                       # stash éventuels
   ```

4. **Structure du projet** :
   - `ls` racine
   - Si petit : `tree -L 2 -I 'node_modules|.venv|vendor|.terraform|dist|build'`

5. **Synthétiser** au format ci-dessous

## Format de sortie

```
## Reprise de contexte — <nom projet>

### Statut projet
- **Objectif** : <de CLAUDE.md/README>
- **Stack** : <techno principale>
- **Branche courante** : <branch>
- **Dernière activité** : <dernier commit, date>

### Travail en cours (non commité)
<résumé `git diff --stat` / `git status`>

### Points clés en mémoire
<memories project_* résumées>

### Décisions récentes
<3-5 dernières ADR ou commits structurants>

### Ce qui semble en attente
<déduire de l'état actuel : fichiers nouveaux non commités, branches en cours, TODOs>

### Prochaine étape suggérée
<proposition basée sur l'état observé — à valider par l'utilisateur>
```

## Règles

- **Silencieux** sur les lectures (ne pas narrer « je lis ceci… je lis cela… »)
- **Concis** : viser 15-25 lignes de sortie, pas un roman
- **Actionnable** : finir par une proposition concrète
- **Comparer memory vs code** : si divergence, signaler (memory potentiellement obsolète)

## Quand invoquer

- Nouvelle session après reboot
- Gap de plusieurs jours sur un projet
- « On en était où ? »
- Premier entry point sur un projet
