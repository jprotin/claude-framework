# Changelog

Les évolutions notables du framework, de la plus récente à la plus ancienne
(format [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/)).

## [1.1.0] — 2026-10-27

> **En bref** — Le framework sait maintenant piloter une feature de bout en bout (`/feature`) et
> la suivre dans une seule interface web pour tous les projets, avec un tableau de bord et un
> kanban. Les documents produits sont écrits pour être lus par tous, et les artéfacts peuvent
> être versionnés. `settings.json` est désormais généré, et le garde-fou des commandes
> dangereuses est renforcé.

### Ajouté
- **Pipeline `/feature`** : cadrage, conception, découpage, développement, vérification et
  documentation d'une feature, avec relecture critique à chaque étape et validation par
  l'utilisateur.
- **Interface web unique** (`/feature-serve`) : un onglet par projet, un tableau de bord, une
  page « En ce moment » (en cours, bloqué, attend votre Go) et un kanban par projet, mis à jour
  en direct (`feature-hub.sh`, `feature-tasks.py`).
- **Charte de rédaction** (`templates/charte-redaction.md`) : « En bref » en tête, mots
  courants, détail technique replié ; appliquée par les agents, `/adr` et `/feature`.
- **Versionnement des artéfacts**, activable par projet : archive dans un repo privé central
  (`feature-archive.sh`) et livrables finaux dans `docs/features/` du projet (`feature-promote.sh`).
- **Groupe de prérequis `agentic`** (MkDocs < 2), installé par `install.sh`.
- **Politique RTK** versionnée (`docs/rtk-policy.md`).

### Modifié
- `install.sh` génère `~/.claude/settings.json` (base du repo + overlay local non versionné)
  au lieu d'un lien symbolique.
- Hook `danger-guard` durci (options globales, commandes enchaînées, variantes de push), avec tests.

### Corrigé
- `/feature-serve` démarre correctement (configuration MkDocs et feuille de style).

## [0.1.0] — 2026-06-10

Première version du framework Claude Code.
