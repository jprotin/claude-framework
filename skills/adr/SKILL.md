---
name: adr
description: Génère un Architecture Decision Record (ADR). À invoquer pour documenter une décision technique importante avec son contexte, ses options et sa justification. Déclencheurs : "ADR", "décision architecturale", "documenter le choix de".
---

# Skill : ADR (Architecture Decision Record)

Génère un ADR dans `docs/adr/` selon le format léger Michael Nygard + ajouts.

## Emplacement

`docs/adr/NNNN-titre-en-kebab-case.md`

`NNNN` = 4 chiffres, séquentiel (0001, 0002, …). Chercher le dernier pour incrémenter.

## Template

```markdown
# NNNN — <Titre court : décision en elle-même, pas "Comment choisir X">

- **Status** : proposed | accepted | deprecated | superseded by NNNN
- **Date** : YYYY-MM-DD
- **Auteur(s)** : <nom>
- **Tags** : <architecture, sécurité, perf, etc.>

## Contexte

<2-4 paragraphes : quel problème, quelles forces en présence, quelles contraintes.
Factuel. Pas de jugement. Un lecteur 2 ans plus tard doit comprendre *pourquoi* on s'est posé la question.>

## Options envisagées

### Option 1 : <nom>
- **Description** : …
- **Pour** : …
- **Contre** : …
- **Coût** : …

### Option 2 : <nom>
- …

### Option 3 : <nom>
- …

## Décision

<1-2 paragraphes : quelle option retenue. Commencer par « Nous retenons … »>

## Conséquences

### Positives
- …

### Négatives / Coûts
- …

### Neutres / À surveiller
- …

## Alternatives non explorées (et pourquoi)

- **X** : exclu car …
- **Y** : non pertinent car …

## Références

- <liens vers docs, tickets, discussions, RFC externes, benchmarks>
- <autres ADR liés>
```

## Procédure d'invocation

1. Demander à l'utilisateur :
   - Titre / sujet de la décision
   - Contexte court (si pas déjà dans la conversation)
   - Options envisagées (au moins 2)
   - Décision retenue
   - Contraintes / forces en présence

2. Chercher le prochain numéro libre :
   ```bash
   ls docs/adr/*.md 2>/dev/null | sort | tail -1
   ```

3. Créer le fichier `docs/adr/NNNN-titre.md` en remplissant le template

4. Proposer d'ajouter au `README.md` racine une référence vers cet ADR si décision structurante

5. Ne pas commit — laisser l'utilisateur valider

## Règles

- **Court et précis** : 1-3 pages max. Un ADR illisible ne sera pas lu.
- **Factuel** sur le contexte, **argumenté** sur la décision
- **Immutable une fois accepté** : pour changer une décision, écrire un nouvel ADR qui "superseded by"
- **Jamais accepter sans 2+ options envisagées** : sinon c'est de la doc, pas une décision
- **Date au format ISO** (YYYY-MM-DD)
