---
name: debug
description: Applique une méthode structurée pour débugger un problème (repro → isoler → hypothèse → test → fix). À invoquer pour tout bug, comportement inattendu, régression. Déclencheurs : "debug", "ne marche pas", "erreur", "bug", "pourquoi ça plante".
---

# Skill : Debug structuré

Méthode rigoureuse pour éliminer le guessing et aller vite à la cause racine.

## Méthode — en 6 étapes

### 1. Reproduire
- Obtenir les **étapes exactes** pour reproduire
- Reproduire localement si possible (sinon, logs + snapshot)
- Si non reproductible : noter, documenter, mais ne pas "fixer à l'aveugle"

### 2. Caractériser
- **Qu'est-ce qui se passe** ? (symptôme précis, message d'erreur exact)
- **Qu'est-ce qu'on attendait** ?
- **Depuis quand** ? (git bisect si régression, changelog d'un prestataire)
- **Partiel ou total** ? (100% des cas, ou certaines conditions ?)
- **Impact** : combien d'users, blockant, workaround existant ?

### 3. Isoler
Réduire progressivement le scope :
- **Environnement** : dev vs staging vs prod ?
- **Route / fonction** : précisément laquelle ?
- **Input** : quel payload précis déclenche ?
- **Composant** : front ? API ? DB ? cache ? network ?
- **Version** : quelle version du code/deps ?

Techniques :
- `git bisect` entre un commit OK et un commit KO
- Commenter/désactiver progressivement (dichotomie)
- Logs ajoutés à des points clés (entrée/sortie de fonctions)
- Mesurer avec des outils : profiler, network tab, strace…

### 4. Formuler des hypothèses
- **Pas une seule** : en lister 2-4 plausibles
- **Ordonner par probabilité** × facilité de test
- **Expliciter** : « Si H est vraie, alors X devrait se passer quand je fais Y »

### 5. Tester
- Tester **une hypothèse à la fois**
- **Observer** sans modifier avant de comprendre
- Noter le résultat (confirmé / infirmé / inconcluant)
- Si inconcluant, affiner l'hypothèse ou remonter d'un niveau

### 6. Fixer à la cause racine
- **Cause racine**, pas symptôme : appliquer les **5 Whys**
  - Pourquoi ça plante ? → Parce que X est null
  - Pourquoi X est null ? → Parce que l'API Y renvoie vide
  - Pourquoi Y renvoie vide ? → Parce que le cache Z a expiré sans refresh
  - Pourquoi le cache n'a pas refresh ? → Parce que le cron est en erreur
  - Pourquoi le cron est en erreur ? → Parce que la connexion à K a timeout en silence
  → **Vrai fix** : retry + alerting sur le cron, pas `if (X == null) return []` dans le frontend
- **Tester le fix** : que le bug initial disparaisse **ET** qu'aucun cas existant ne casse
- **Ajouter un test** qui aurait attrapé le bug (évite la régression)

## Heuristiques utiles

- **Ça marchait avant** → `git log -p` sur le fichier suspect, `git bisect`
- **Erreur intermittente** → race condition, cache, timezone, clock drift, réseau
- **Timeout** → lock DB, déadlock, pool saturé, dépendance lente
- **Fonctionne en dev, pas en prod** → config diff, secrets diff, volumes, proxy, CORS, versions
- **Marche localement, pas en CI** → path absolu, env variable, timezone, ordre de tests
- **Erreur sans stack trace utile** → logs structurés insuffisants, relever niveau de log
- **Fuite mémoire** → profile heap, chercher fermetures non libérées, caches non bornés
- **"ça plante en silence"** → try/except trop large qui avale, retry masquant

## Outils par couche

| Couche | Outils |
|---|---|
| Code (runtime) | debugger IDE, `print`/log, stack trace, profiler |
| Process | `strace`, `ltrace`, `ps`, `lsof`, `top` |
| I/O | `iostat`, `iotop` |
| Network | `tcpdump`, `wireshark`, `curl -v`, `mtr`, `netstat`/`ss`, `dig` |
| HTTP | `curl -v`, browser DevTools Network, MITM proxy (mitmproxy) |
| Container | `docker logs`, `docker exec`, `kubectl logs`, `kubectl describe`, `kubectl events` |
| DB | `EXPLAIN ANALYZE`, slow query log, `pg_stat_activity` / `SHOW PROCESSLIST` |
| Cloud | logs centralisés (CloudWatch, Stackdriver, Loki, Datadog) |

## Format de rapport

À la fin d'une session debug :

```
## Debug report

### Symptôme
<description observée>

### Cause racine
<vrai pourquoi, 5-Whys si pertinent>

### Fix appliqué
<ce qui a changé et pourquoi ça corrige>

### Test de non-régression
<test ajouté, scénario validé>

### Prévention
<monitoring / alerte / process à améliorer pour détecter plus tôt la prochaine fois>
```

## Anti-patterns — à éviter

- Modifier 5 choses en même temps → on ne sait plus ce qui a corrigé
- "Ça marche, passons à autre chose" sans comprendre pourquoi
- Ajouter `try/except: pass` pour faire disparaître le message
- Fixer le symptôme (`if null: return []`) sans fixer la cause
- Blamer la lib / le réseau sans investiguer
- Redémarrer jusqu'à ce que ça marche
- Pas de test ajouté → récurrence garantie
