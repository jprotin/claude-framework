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

**Projet** : ${PROJECT_NAME}
**Mode** : ${MODE}
**Phase courante** : Spec (Phase 1)
**Démarré le** : $(date +"%d/%m/%Y")

## Progression

| Phase | Statut |
|---|---|
| 1 — Spec & ADR | En cours |
| 2 — Plan | En attente |
| 3 — Découpage + Tests | En attente |
| 4 — Implémentation | En attente |
| 5 — Validation | En attente |
| 6 — Documentation | En attente |

## Documents

- [Analyse & Spec](spec/analysis.md)
- [Challenge de la spec](spec/analysis-challenge.md)
- [Plan](plan/plan.md)
- [Tasks](tasks/tasks.md)
- [Stratégie de tests](tasks/test-strategy.md)
- [Rapport de validation](validation/final-report.md)
- [Documentation](docs/feature-doc.md)
EOF

# ── .pages pour navigation ordonnée ───────────────────────────────────────

cat > "${FEATURE_DIR}/.pages" <<EOF
title: "${SLUG}"
nav:
  - Vue d'ensemble: index.md
  - Spec & ADR: spec
  - Plan: plan
  - Tasks: tasks
  - Validation: validation
  - Documentation: docs
EOF

cat > "${FEATURE_DIR}/spec/.pages" <<EOF
title: "Spec & ADR"
nav:
  - Analyse: analysis.md
  - Challenge: analysis-challenge.md
  - Final: analysis-final.md
  - ADR: adr-draft.md
EOF

cat > "${FEATURE_DIR}/plan/.pages" <<EOF
title: "Plan"
nav:
  - Plan: plan.md
  - Challenge: plan-challenge.md
  - Final: plan-final.md
EOF

cat > "${FEATURE_DIR}/tasks/.pages" <<EOF
title: "Tasks"
nav:
  - Tasks: tasks.md
  - Challenge: tasks-challenge.md
  - Stratégie de tests: test-strategy.md
  - Checklist: checklist.md
EOF

cat > "${FEATURE_DIR}/validation/.pages" <<EOF
title: "Validation"
nav:
  - Rapport final: final-report.md
  - Sécurité: security.md
  - Code review: review.md
  - Doc sync: doc-sync.md
EOF

cat > "${FEATURE_DIR}/docs/.pages" <<EOF
title: "Documentation"
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
