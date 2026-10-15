# Skill : /feature — Pipeline Agentic Coding

Orchestre le pipeline complet de développement d'une feature : spec → challenge → plan → découpage → implémentation → validation → documentation.

**Déclencheurs** : `/feature`, "nouvelle feature", "pipeline agentic", "start feature"

---

## Procédure

### Étape 0 — Parsing de l'invocation

Détecter si l'utilisateur a passé des flags :
- `/feature --auto "description"` → mode autonome (Workflow phases 2-6)
- `/feature --interactive "description"` → mode semi-interactif (gate après chaque phase)
- `/feature "description"` → demander le mode (voir ci-dessous)

Si aucun flag, utiliser AskUserQuestion :
- Question : « Mode de pipeline pour cette feature ? »
- Options :
  - **Auto** : s'exécute seul après Phase 1, te revient avec un rapport complet
  - **Interactif** : s'arrête après chaque phase pour validation

### Étape 1 — Initialisation

Générer le `feature-slug` : lowercase, tirets, max 40 chars, depuis la description.
Exemple : "Authentification SSO avec SAML" → `auth-sso-saml`

Exécuter le script d'initialisation :
```bash
bash ~/.claude/bin/feature-init.sh "<feature-slug>" "<projet-courant>"
```

Ce script crée l'arborescence `.claude/features/<slug>/` et le fichier `meta.json`.

Confirmer à l'utilisateur : « Feature `<slug>` initialisée. Phase 1 — Spec en cours... »

### Étape 2 — Phase 1 : SPEC (toujours interactive)

**Étape 2a — spec-writer**

Lancer un agent `spec-writer` avec ce brief :
```
Feature slug : <slug>
Demande : <description complète>
Chemin de sortie : <chemin-absolu>/.claude/features/<slug>/spec/
Contexte projet : <résumé de la stack détectée>
```

Attendre la complétion. L'agent écrit `spec/analysis.md` (+ `spec/adr-draft.md` si pertinent + `spec/index.md`).

**Étape 2b — challenger (spec)**

Lancer un agent `challenger` **en fork** (contexte propre, sans biais auteur) avec ce brief :
```
Type de phase : spec
Feature slug : <slug>
Document à challenger : <lire le contenu de spec/analysis.md>
```

L'agent écrit `spec/analysis-challenge.md`.

**Étape 2c — Présentation à l'utilisateur**

Afficher un résumé structuré :
```
## Phase 1 terminée — Spec & Challenge

### Spec produite
<résumé en 5-8 bullets des RF principales et contraintes clés>

### Points soulevés par le Challenger
<liste des bloquants et majeurs du challenge — 1 ligne chacun>

### Documents disponibles
- spec/analysis.md
- spec/analysis-challenge.md
<si ADR> - spec/adr-draft.md

Interface web : http://localhost:8888 (lancer `feature-serve` si pas démarré)
```

**Étape 2d — Gate utilisateur (obligatoire)**

Utiliser AskUserQuestion :
- Question : « Validation de la Phase 1 ? »
- Options :
  - **Valider** : continuer avec la spec telle quelle
  - **Challenger à mon tour** : j'ai des remarques à intégrer (l'utilisateur saisit ses remarques dans "Other")
  - **Modifier la spec** : j'ouvre les fichiers moi-même, je reviendrai

Si l'utilisateur choisit "Challenger à mon tour" : intégrer ses remarques dans `spec/analysis-final.md` (synthèse spec + challenge auto + challenge user). Sinon copier `analysis.md` → `analysis-final.md`.

Mettre à jour `meta.json` : `"current_phase": 2`.

### Étape 3 — Phases 2-6

#### Si mode AUTO

Lancer le Workflow avec le script `pipeline.js` :
```javascript
// Appeler via l'outil Workflow avec le script skills/feature/pipeline.js
// Passer en args : { slug, featurePath, specPath }
```

Communiquer à l'utilisateur : « Pipeline autonome lancé. Je te reviens avec le rapport complet. Interface web disponible sur http://localhost:8888 pour suivre la progression. »

Attendre la notification de fin du Workflow. Puis afficher le rapport final (voir format ci-dessous).

#### Si mode INTERACTIF

Exécuter chaque phase séquentiellement avec gate utilisateur après chaque phase.

**Phase 2 — PLAN**
1. Lancer agent `Plan` avec : spec-final + contexte projet
   - Output : `plan/plan.md`
2. Lancer agent `challenger` (type: plan) sur `plan/plan.md`
   - Output : `plan/plan-challenge.md`
3. Gate : afficher synthèse + AskUserQuestion (Valider / Challenger / Modifier)
4. Si validation → `plan/plan-final.md`

**Phase 3 — DÉCOMPOSITION + STRATÉGIE DE TESTS** (parallel dans le Workflow, séquentiel en interactif)
1. Lancer agent `decomposer` : `plan-final.md` + `spec/analysis-final.md`
   - Output : `tasks/tasks.md` + `tasks/checklist.md`
2. Lancer agent `test-designer` : `spec/analysis-final.md` + `plan-final.md`
   - Output : `tasks/test-strategy.md`
3. Lancer agent `challenger` (type: decompose) sur `tasks/tasks.md`
   - Output : `tasks/tasks-challenge.md`
4. Gate : afficher synthèse + AskUserQuestion

**Phase 4 — IMPLÉMENTATION** (par task)

Pour chaque task dans `tasks/tasks.md` (statut `pending`) :
1. Afficher : « Implémentation TASK-XX — <titre> »
2. Implémenter selon les instructions de la task
3. Lancer agent `code-reviewer` sur le diff de cette task
4. Si bloquants : corriger avant de passer à la suivante
5. Mettre à jour le statut de la task dans `tasks/tasks.md`

En mode interactif : gate après chaque block de tasks (pas chaque task individuelle).

**Phase 5 — VALIDATION GLOBALE**
1. Lancer agent `security-auditor` sur tout le diff de la feature
   - Output : `validation/security.md`
2. Lancer agent `code-reviewer` sur tout le diff
   - Output : `validation/review.md`
3. Lancer agent `doc-sync` sur les fichiers modifiés
   - Output : `validation/doc-sync.md`
4. Consolider en `validation/final-report.md`
5. Gate (interactif) ou rapport final (auto)

**Phase 6 — DOCUMENTATION**
1. Rédiger `docs/feature-doc.md` depuis tous les artéfacts produits
2. Proposer l'entrée CHANGELOG
3. Mettre à jour `meta.json` : `"status": "done"`

### Format du rapport final (mode auto)

```
## Rapport final — <feature-slug>

### Phases complétées
- ✅ Phase 1 — Spec (validée par utilisateur)
- ✅ Phase 2 — Plan
- ✅ Phase 3 — Découpage (X tasks, Y pts)
- ✅ Phase 4 — Implémentation
- ✅ Phase 5 — Validation
- ✅ Phase 6 — Documentation

### Implémentation
<résumé : N fichiers modifiés, N créés, diff stat>

### Validation
- Sécurité : <verdict security-auditor>
- Code review : <verdict — N bloquants résolus>
- Doc sync : <verdict>

### Points d'attention
<items des rapports de validation qui méritent attention>

### Prochaine étape
<proposition : commit sur feature branch, PR vers develop, etc.>

Interface web : http://localhost:8888/<feature-slug>
```

---

## Règles

- **Phase 1 toujours interactive** — sans exception
- **Ne jamais commiter** — le pipeline prépare, l'utilisateur valide et commite
- **Mettre à jour meta.json** après chaque phase (permet de reprendre)
- **Si une phase échoue** : arrêter, reporter le problème, ne pas silently skip
- **Token awareness** : en mode auto sur grosse feature, signaler si > 50% budget tokens consommé
- **Interface web** : rappeler l'URL à chaque étape significative

## Reprise d'une feature interrompue

Si le répertoire `.claude/features/<slug>/` existe déjà avec un `meta.json` :
```bash
cat .claude/features/<slug>/meta.json
```
Reprendre à `current_phase`. Informer l'utilisateur de l'état trouvé.
