---
name: analyze
description: Force l'application du workflow méta (Analyse → Explication → Plan → Attente du Go) sur une demande. À invoquer quand j'ai tendance à sauter sur l'implémentation, ou quand la demande est complexe et mérite une analyse structurée avant toute action.
---

# Skill : Analyse structurée

Quand ce skill est invoqué, j'applique **strictement** le workflow méta, même si la demande semble simple.

## Structure de sortie obligatoire

```
## 1. Ma compréhension
<reformulation de la demande en 2-3 phrases, mes propres mots>
<pointe les ambiguïtés ou hypothèses implicites>

## 2. Contexte pertinent
<ce que j'ai observé dans le repo / memory / git qui influence la réponse>
<fichiers / commits / configs concernés>

## 3. Contraintes et risques
<contraintes techniques, dépendances, prérequis>
<risques identifiés : sécurité, perf, compatibilité, effet de bord>

## 4. Options envisagées
### Option A : <nom court>
- Description
- Pour : ...
- Contre : ...

### Option B : <nom court>
- …

(au minimum 2 options sauf cas trivial, où expliquer pourquoi une seule)

## 5. Recommandation
<option retenue + raison>
<conditions sous lesquelles cette reco change>

## 6. Plan d'action
1. Étape concrète 1
2. Étape concrète 2
3. ...

## 7. Questions avant Go
<questions bloquantes s'il y en a, sinon indiquer "pas de question bloquante">

---

**En attente du Go.**
```

## Règles

- Ne rien implémenter tant que le Go n'est pas donné
- Les lectures (grep, read, glob) sont autorisées pour *préparer* l'analyse
- Si la demande est triviale au point que ce format est absurde, le dire explicitement et demander confirmation ("est-ce que tu veux vraiment le format analyze ou une action directe ?")
- Si la demande est ambiguë, la section "Questions avant Go" est la section la plus importante

## Quand auto-invoquer

Ce skill devrait s'appliquer **automatiquement** (via CLAUDE.md global) sur toute demande non triviale. Le `/analyze` explicite est utile pour :
- Forcer le format quand j'ai dérivé
- Demander une analyse approfondie sur un sujet apparemment simple
- Préparer une décision structurée (mini-ADR)
