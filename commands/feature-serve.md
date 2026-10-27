---
description: Démarre l'interface web MkDocs Material pour naviguer les artéfacts des features de tous les projets inscrits, un onglet par projet (spec, plan, tasks, validation, docs). Hot-reload automatique.
---
Lance l'interface web unique de navigation des features (tous projets). Le projet courant est inscrit au passage s'il a des features.

Exécute la commande suivante dans le terminal :

```bash
bash ~/.claude/bin/feature-serve.sh
```

L'interface sera disponible sur http://localhost:8888

Si un port différent est souhaité, passer en argument : `feature-serve 9000`

Projets inscrits : `bash ~/.claude/bin/feature-hub.sh list`
