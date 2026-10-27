export const meta = {
  name: 'feature-pipeline',
  description: 'Pipeline agentic coding phases 2-6 : plan → décomposition → implémentation → validation → documentation',
  phases: [
    { title: 'Plan', detail: 'Plan + challenge' },
    { title: 'Decompose', detail: 'Tasks + test strategy + challenge' },
    { title: 'Implement', detail: 'Implémentation par task avec review inline' },
    { title: 'Validate', detail: 'Security + code review + doc-sync' },
    { title: 'Document', detail: 'Documentation finale + changelog' },
  ],
}

// args : { slug, featurePath, projectPath }
const { slug, featurePath, projectPath } = args

const specPath = `${featurePath}/spec/analysis-final.md`

// Chaque document est lu dans l'interface web par des non-spécialistes.
const READABLE = `Rédaction : applique la charte ~/.claude/templates/charte-redaction.md (lis-la avant d'écrire) :
« En bref » de 3 à 5 phrases simples sous le titre, aucun identifiant ni sigle seul dans la partie
visible, détail technique replié dans <details markdown="1">, glossaire dès 3 termes techniques.`

// ─── Phase 2 : PLAN ────────────────────────────────────────────────────────

const [planResult, planChallenge] = await pipeline(
  [{ role: 'planner' }, { role: 'challenger' }],
  async (item) => {
    if (item.role === 'planner') {
      return agent(
        `Tu es un architecte logiciel senior. Lis la spec feature à ${specPath} et produis un plan d'implémentation détaillé.

Règles :
- Liste les composants à créer / modifier
- Identifie les dépendances entre composants
- Propose une approche technique pour chaque composant (pas le code, la stratégie)
- Identifie les risques techniques
- Estime la complexité globale (S/M/L/XL)
- Écris le plan dans ${featurePath}/plan/plan.md
- Structure : titre en mots, « En bref », « Les étapes » (liste numérotée ou schéma Mermaid),
  puis un H2 par composant (H3 par décision technique), le détail technique replié

${READABLE}`,
        {
          label: `plan:${slug}`,
          phase: 'Plan',
        }
      )
    }
  },
  async (plannerOutput) => {
    return agent(
      `Challenge adversarial du plan d'implémentation.

Plan à challenger : ${featurePath}/plan/plan.md
Spec de référence : ${specPath}
Type de phase : plan
Feature slug : ${slug}

Lis le plan et produis une critique structurée dans ${featurePath}/plan/plan-challenge.md.
Utilise le format du challenger agent : En bref, Bloquants / Majeurs / Mineurs / Questions ouvertes.`,
      {
        label: `challenge-plan:${slug}`,
        phase: 'Plan',
      }
    )
  }
)

// ─── Phase 3 : DÉCOMPOSITION + TEST STRATEGY (parallèle) ───────────────────

const [decomposeResult, testStrategyResult] = await parallel([
  () => agent(
    `Décompose le plan d'implémentation en tasks atomiques.

Plan : ${featurePath}/plan/plan.md
Spec : ${specPath}
Feature slug : ${slug}
Chemin de sortie : ${featurePath}/tasks/

Produis :
1. ${featurePath}/tasks/tasks.md — tasks ordonnées, estimées, avec critères de done
2. ${featurePath}/tasks/checklist.md — checklist qualité pré-commit

Utilise les types : SETUP, SCHEMA, MODEL, SERVICE, API, UI, TEST, DOC, INFRA
Chaque task < 3 pts, sinon re-découper.`,
    {
      label: `decompose:${slug}`,
      phase: 'Decompose',
    }
  ),
  () => agent(
    `Conçois la stratégie de tests pour cette feature.

Spec : ${specPath}
Plan : ${featurePath}/plan/plan.md
Feature slug : ${slug}

Produis ${featurePath}/tasks/test-strategy.md avec :
- Tests unitaires (must/should/nice-to-have)
- Tests d'intégration
- Tests E2E sur flux critiques
- Cas limites et edge cases identifiés
- Fixtures suggérées
- Couverture cible

Ne pas écrire le code des tests — plan uniquement.`,
    {
      label: `test-strategy:${slug}`,
      phase: 'Decompose',
    }
  ),
])

// Challenge du découpage (après les deux outputs)
const decomposeChallenge = await agent(
  `Challenge adversarial du découpage en tasks.

Tasks à challenger : ${featurePath}/tasks/tasks.md
Stratégie de tests : ${featurePath}/tasks/test-strategy.md
Type de phase : decompose
Feature slug : ${slug}

Produis ${featurePath}/tasks/tasks-challenge.md.
Focus : tasks mal bornées, dépendances manquantes, estimations irréalistes, tests oubliés.`,
  {
    label: `challenge-decompose:${slug}`,
    phase: 'Decompose',
  }
)

// ─── Phase 4 : IMPLÉMENTATION ──────────────────────────────────────────────

const implementResult = await agent(
  `Implémente toutes les tasks de la feature ${slug}.

Tasks : ${featurePath}/tasks/tasks.md
Checklist : ${featurePath}/tasks/checklist.md
Stratégie de tests : ${featurePath}/tasks/test-strategy.md
Spec : ${specPath}
Plan : ${featurePath}/plan/plan.md

Suivi (lu par le kanban de l'interface web) : si ${featurePath}/tasks/tasks.json n'existe pas,
le créer d'abord avec : python3 ~/.claude/bin/feature-tasks.py import "${featurePath}"

Procédure pour chaque task (dans l'ordre des dépendances) :
1. Lire la task complète, puis : python3 ~/.claude/bin/feature-tasks.py set "${featurePath}" <ID> doing
2. Implémenter selon les fichiers concernés listés
3. Vérifier le critère de done
4. python3 ~/.claude/bin/feature-tasks.py set "${featurePath}" <ID> done
   (bloqué : set "${featurePath}" <ID> blocked --note "<raison en une phrase simple>")
5. Si un test est requis pour cette task, l'écrire

Respecter les patterns existants du projet à ${projectPath}.
Ne pas modifier de fichiers hors scope des tasks.`,
  {
    label: `implement:${slug}`,
    phase: 'Implement',
  }
)

// ─── Phase 5 : VALIDATION (parallèle) ─────────────────────────────────────

const [securityResult, reviewResult, docSyncResult] = await parallel([
  () => agent(
    `Audit sécurité de l'implémentation de la feature ${slug}.

Effectue un git diff pour voir tous les changements introduits par cette feature.
Produis un rapport de sécurité dans ${featurePath}/validation/security.md.

Focus : secrets exposés, injections, authz, surface d'attaque introduite, dépendances vulnérables.
Format : Critique / Important / Observation.`,
    {
      label: `security:${slug}`,
      phase: 'Validate',
    }
  ),
  () => agent(
    `Review de code de l'implémentation de la feature ${slug}.

Effectue un git diff pour voir tous les changements introduits.
Produis un rapport dans ${featurePath}/validation/review.md.

Checklist : correction, qualité, cohérence, tests, nommage, duplication, perf.
Format : Bloquants / Recommandations / Observations / Verdict.`,
    {
      label: `review:${slug}`,
      phase: 'Validate',
    }
  ),
  () => agent(
    `Vérifie la cohérence entre le code et la documentation pour la feature ${slug}.

Parcours les fichiers modifiés par la feature. Vérifie :
- README à jour si surface publique modifiée
- Docstrings sur API publique
- env.example si nouvelles variables
- CHANGELOG si entrée ajoutée

Produis un rapport dans ${featurePath}/validation/doc-sync.md.`,
    {
      label: `doc-sync:${slug}`,
      phase: 'Validate',
    }
  ),
])

// Rapport de validation consolidé
const validationReport = await agent(
  `Consolide les rapports de validation de la feature ${slug} en un rapport final.

Inputs :
- Security : ${featurePath}/validation/security.md
- Code review : ${featurePath}/validation/review.md
- Doc sync : ${featurePath}/validation/doc-sync.md

Produis ${featurePath}/validation/final-report.md avec :
- « En bref » : peut-on livrer ? ce qu'il reste à faire, en mots simples
- Verdict global (prêt / corrections requises / refonte)
- Points bloquants à traiter avant merge
- Recommandations non bloquantes
- Résumé des validations passées (détail replié)

${READABLE}`,
  {
    label: `validation-report:${slug}`,
    phase: 'Validate',
  }
)

// ─── Phase 6 : DOCUMENTATION ───────────────────────────────────────────────

const docResult = await agent(
  `Rédige la documentation finale de la feature ${slug}.

Synthétise l'ensemble du travail produit :
- Spec : ${featurePath}/spec/analysis-final.md
- Plan : ${featurePath}/plan/plan.md
- Tasks : ${featurePath}/tasks/tasks.md
- Validation : ${featurePath}/validation/final-report.md

Produis :
1. ${featurePath}/docs/feature-doc.md — documentation de la feature, lisible par toute personne
   qui la découvre (chef de projet, client, nouvel arrivant) :
   - « En bref » : ce que fait la feature et pour qui
   - Ce que ça change pour les utilisateurs, et comment s'en servir
   - Points d'attention (limites connues, exploitation)
   - Détails techniques repliés : architecture, décisions, comment tester
   - Liens vers les ADR si présents

${READABLE}

2. Propose une entrée CHANGELOG (format Keep a Changelog) dans ${featurePath}/docs/changelog-entry.md

Met à jour ${featurePath}/meta.json : "status" → "done", "completed" → date du jour.`,
  {
    label: `doc:${slug}`,
    phase: 'Document',
  }
)

// ─── Rapport final ─────────────────────────────────────────────────────────

return {
  slug,
  featurePath,
  phases: {
    plan: { status: 'done', challenge: planChallenge },
    decompose: { status: 'done', tasks: decomposeResult, tests: testStrategyResult },
    implement: { status: 'done' },
    validate: { status: 'done', security: securityResult, review: reviewResult },
    document: { status: 'done' },
  },
  webUrl: 'http://localhost:8888',
  nextStep: `Vérifier ${featurePath}/validation/final-report.md, puis commiter la feature branch.`,
}
