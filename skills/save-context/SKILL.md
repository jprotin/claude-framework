---
name: save-context
description: Snapshot du contexte projet actuel en auto-memory. À invoquer à la fin d'une session productive, avant un reboot, ou quand on atteint une décision/étape importante. Persiste ce qui n'est pas dérivable du code.
---

# Skill : Save Context

Sauvegarde en auto-memory ce qui est utile pour reprendre la session plus tard ou lors d'un autre projet.

## Procédure

1. **Identifier ce qui est NON-dérivable du code** :
   - Décisions prises pendant la session (et leur raison)
   - État en cours d'une tâche (où on en est, qu'est-ce qui reste)
   - Contraintes découvertes (ex: « l'API X rate-limite à 100/min »)
   - Pistes abandonnées (et pourquoi — évite de les re-tenter)
   - Déblocage subtil (la vraie cause d'un bug, pas la ligne de code changée)

2. **Identifier ce qui est DÉJÀ dans :**
   - Le code / la doc / les commits → **ne pas dupliquer en mémoire**
   - Des memories existantes → **mettre à jour plutôt que créer**

3. **Choisir le bon type :**
   - `project` : état, décision, contrainte, deadline du projet courant
   - `feedback` : règle ou préférence confirmée par l'utilisateur
   - `user` : info durable sur l'utilisateur (rôle, niveau, préférences générales)
   - `reference` : pointeur vers un système externe

4. **Écrire les fichiers** dans `~/.claude/projects/<hash>/memory/` :
   - Un fichier par memory
   - Frontmatter : `name`, `description`, `type`
   - Contenu structuré avec `**Why:**` et `**How to apply:**` pour feedback/project
   - Ajouter la ligne dans `MEMORY.md`

5. **Confirmer** à l'utilisateur ce qui a été sauvegardé (résumé 3-5 lignes)

## Format mémoire

```markdown
---
name: <titre court>
description: <une ligne qui explique quand cette memory est pertinente>
type: <user|feedback|project|reference>
---

<contenu>

**Why:** <raison/contexte>
**How to apply:** <quand et comment appliquer>
```

## Exemples de déclencheurs pour ce skill

- « Sauvegarde où on en est »
- « Note cette décision »
- « Je dois reboot, garde le contexte »
- « Retiens le dernier point qu'on a vu »

## Anti-patterns — NE PAS sauvegarder

- « J'ai édité `file.tf` ligne 42 » (git log le sait)
- « L'architecture est en X modules » (le code le montre)
- « La stack est Terraform + OVH » (le repo le montre)
- Récit chronologique d'une session

Ce qui est sauvable = ce qu'un nouveau venu ne pourrait pas deviner en lisant le code.
