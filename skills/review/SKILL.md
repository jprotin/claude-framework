---
name: review
description: Revue pré-livraison structurée. À invoquer avant un commit, une release, un merge. Couvre qualité code, sécurité, tests, doc, cohérence. Déclencheurs : "review", "relecture", "pré-merge", "avant commit".
---

# Skill : Revue pré-livraison

Applique une revue structurée sur les changements en cours. Objectif : détecter ce qui doit être corrigé **avant** le commit/merge.

## Scope à couvrir

### 1. Qualité code
- [ ] Nommage explicite (pas d'abréviations, pas de `tmp`/`x`)
- [ ] Fonctions courtes (< 50 lignes, < 3 niveaux d'imbrication)
- [ ] Pas de code commenté / mort
- [ ] Pas de `TODO`/`FIXME` sans ticket
- [ ] Pas de duplication évidente
- [ ] Convention de style respectée (pre-commit doit passer)
- [ ] Commentaires sur le "pourquoi", pas le "quoi"

### 2. Correction fonctionnelle
- [ ] Les cas d'erreur sont gérés (pas de `try/except: pass`)
- [ ] Les entrées externes sont validées
- [ ] Pas d'effet de bord inattendu
- [ ] Compatibilité ascendante préservée si API publique

### 3. Tests
- [ ] Tests ajoutés/modifiés pour les changements
- [ ] Tests actuels passent
- [ ] Cas limites testés (vide, null, extrêmes)
- [ ] Coverage raisonnable sur le nouveau code

### 4. Sécurité
- [ ] Pas de secret, token, mdp hardcodé
- [ ] Pas de SQL concaténé / command injection / XSS
- [ ] Auth + authz en place sur endpoints protégés
- [ ] Logs sans info sensible (PII, secrets, tokens)
- [ ] Deps sans CVE critique

### 5. Performance
- [ ] Pas de N+1 évident
- [ ] Index sur nouvelles queries fréquentes
- [ ] Pas de boucle O(n²) sur collection potentiellement large
- [ ] Pas de blocage I/O dans code async

### 6. Infra / config
- [ ] Variables d'env documentées (`.env.example` à jour)
- [ ] Migrations réversibles si applicable
- [ ] Pas de breaking change sur API/events non signalé

### 7. Documentation
- [ ] README à jour si comportement externe change
- [ ] CHANGELOG mis à jour (si le projet en a)
- [ ] Commentaires/docstrings sur API publique
- [ ] Commit message clair

### 8. Cohérence projet
- [ ] Respect des patterns existants
- [ ] Pas de nouveau pattern introduit sans justification
- [ ] Stack/deps cohérente avec le reste

## Procédure

1. **Inspecter les changements** : `git diff`, `git diff --staged`
2. **Lire les fichiers modifiés** en entier (pas juste le diff)
3. **Checker la checklist** ci-dessus en trois passes :
   - Passe 1 : correction (bugs, sécurité)
   - Passe 2 : qualité (lisibilité, tests, doc)
   - Passe 3 : cohérence (patterns, style)
4. **Déléguer** si pertinent :
   - Scan sécurité profond → sous-agent `security-auditor`
   - Cohérence code globale → sous-agent `code-reviewer`
5. **Produire un rapport** structuré ci-dessous

## Format de rapport

```
## Revue : <branche / commit range>

### Bloquants
<items qui doivent être corrigés avant commit/merge>

### Recommandations
<items qui amélioreraient mais ne bloquent pas>

### Observations
<points de vigilance, sans action immédiate>

### Verdict
✅ Prêt à commit/merge
⚠️  À corriger d'abord (<nombre> bloquant(s))
❌ Refonte nécessaire
```
