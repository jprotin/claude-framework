#!/usr/bin/env bash
# feature-init.sh — Initialise l'arborescence d'une feature et inscrit le projet au hub web
# Usage: feature-init.sh <feature-slug> <project-name> [mode: auto|interactive]
set -euo pipefail

SLUG="${1:?Usage: feature-init.sh <slug> <project-name> [auto|interactive]}"
PROJECT_NAME="${2:?Usage: feature-init.sh <slug> <project-name> [auto|interactive]}"
MODE="${3:-interactive}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FEATURES_DIR="${PROJECT_ROOT}/.claude/features"
FEATURE_DIR="${FEATURES_DIR}/${SLUG}"

# Nom vérifié avant toute création : il devient l'onglet du projet dans le hub web.
bash "${SCRIPT_DIR}/feature-hub.sh" validate "${PROJECT_NAME}"

# ── Créer l'arborescence ───────────────────────────────────────────────────

mkdir -p \
  "${FEATURE_DIR}/spec/schemas" \
  "${FEATURE_DIR}/plan" \
  "${FEATURE_DIR}/tasks" \
  "${FEATURE_DIR}/validation" \
  "${FEATURE_DIR}/docs"

# ── meta.json ─────────────────────────────────────────────────────────────

cat > "${FEATURE_DIR}/meta.json" <<EOF
{
  "slug": "${SLUG}",
  "project": "${PROJECT_NAME}",
  "mode": "${MODE}",
  "status": "in-progress",
  "current_phase": 1,
  "started": "$(date -I)",
  "phases": {
    "spec":       { "status": "pending" },
    "plan":       { "status": "pending" },
    "decompose":  { "status": "pending" },
    "implement":  { "status": "pending" },
    "validate":   { "status": "pending" },
    "document":   { "status": "pending" }
  }
}
EOF

# ── index.md racine de la feature ─────────────────────────────────────────

cat > "${FEATURE_DIR}/index.md" <<EOF
# ${SLUG}

> **En bref** — Feature du projet ${PROJECT_NAME}, démarrée le $(date +"%d/%m/%Y") en mode ${MODE}.
> L'avancement tâche par tâche est dans le [kanban du projet](../kanban.md).

## Les étapes

| Étape | Ce qu'on y produit | Statut |
|---|---|---|
| 1 — Cadrage | ce que la feature doit faire, et les décisions d'architecture | En cours |
| 2 — Conception | comment on va la construire | À venir |
| 3 — Découpage | la liste des tâches et la stratégie de tests | À venir |
| 4 — Développement | le code, tâche par tâche | À venir |
| 5 — Vérification | relecture du code, sécurité, documentation | À venir |
| 6 — Documentation | la documentation finale de la feature | À venir |

## Les documents

- [Ce que la feature doit faire (spec)](spec/analysis.md) et sa [relecture critique](spec/analysis-challenge.md)
- [Comment on la construit (plan)](plan/plan.md)
- [Les tâches](tasks/tasks.md) et la [stratégie de tests](tasks/test-strategy.md)
- [Le rapport de vérification](validation/final-report.md)
- [La documentation de la feature](docs/feature-doc.md)
EOF

# ── .pages pour navigation ordonnée ───────────────────────────────────────

cat > "${FEATURE_DIR}/.pages" <<EOF
title: "${SLUG}"
nav:
  - Vue d'ensemble: index.md
  - "1. Cadrage": spec
  - "2. Conception": plan
  - "3. Découpage": tasks
  - "5. Vérification": validation
  - "6. Documentation": docs
EOF

cat > "${FEATURE_DIR}/spec/.pages" <<EOF
title: "1. Cadrage"
nav:
  - Analyse: analysis.md
  - Relecture critique: analysis-challenge.md
  - Version finale: analysis-final.md
  - "Décision d'architecture (ADR)": adr-draft.md
EOF

cat > "${FEATURE_DIR}/plan/.pages" <<EOF
title: "2. Conception"
nav:
  - Plan: plan.md
  - Relecture critique: plan-challenge.md
  - Version finale: plan-final.md
EOF

cat > "${FEATURE_DIR}/tasks/.pages" <<EOF
title: "3. Découpage"
nav:
  - Tâches: tasks.md
  - Relecture critique: tasks-challenge.md
  - Stratégie de tests: test-strategy.md
  - Checklist qualité: checklist.md
EOF

cat > "${FEATURE_DIR}/validation/.pages" <<EOF
title: "5. Vérification"
nav:
  - Rapport final: final-report.md
  - Sécurité: security.md
  - Relecture du code: review.md
  - Cohérence de la doc: doc-sync.md
EOF

cat > "${FEATURE_DIR}/docs/.pages" <<EOF
title: "6. Documentation"
nav:
  - Documentation: feature-doc.md
  - Changelog: changelog-entry.md
EOF

# ── Inscription au hub web (un seul MkDocs pour tous les projets) ─────────

# Non fatal : la feature est déjà créée, seule sa visibilité dans le hub est en jeu.
# Le build rafraîchit l'accueil ; un projet nouveau n'est surveillé qu'au prochain feature-serve.
if bash "${SCRIPT_DIR}/feature-hub.sh" register "${PROJECT_NAME}" "${PROJECT_ROOT}"; then
  bash "${SCRIPT_DIR}/feature-hub.sh" build >/dev/null
else
  echo "[feature-init] Inscription au hub échouée : feature-hub.sh register <nom> pour réessayer."
fi

# ── .gitignore features dir ───────────────────────────────────────────────

GITIGNORE="${PROJECT_ROOT}/.gitignore"
if [[ -f "${GITIGNORE}" ]] && ! grep -q "^\.claude/features" "${GITIGNORE}"; then
  echo "" >> "${GITIGNORE}"
  echo "# Feature pipeline artifacts (local only)" >> "${GITIGNORE}"
  echo ".claude/features/" >> "${GITIGNORE}"
  echo "[feature-init] .gitignore mis à jour"
fi

echo "[feature-init] Feature '${SLUG}' initialisée dans ${FEATURE_DIR}"
HUB_NAME="$(bash "${SCRIPT_DIR}/feature-hub.sh" name-of "${PROJECT_ROOT}" 2>/dev/null || true)"
echo "[feature-init] Interface web (tous projets) : feature-serve → http://localhost:8888/${HUB_NAME:-${PROJECT_NAME}}/${SLUG}/"
