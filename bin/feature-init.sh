#!/usr/bin/env bash
# feature-init.sh — Initialise l'arborescence d'une feature et son mkdocs.yml
# Usage: feature-init.sh <feature-slug> <project-name> [mode: auto|interactive]
set -euo pipefail

SLUG="${1:?Usage: feature-init.sh <slug> <project-name> [auto|interactive]}"
PROJECT_NAME="${2:?Usage: feature-init.sh <slug> <project-name> [auto|interactive]}"
MODE="${3:-interactive}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FEATURES_DIR="${PROJECT_ROOT}/.claude/features"
FEATURE_DIR="${FEATURES_DIR}/${SLUG}"
ASSETS_DIR="${FEATURES_DIR}/assets"  # partagé : extra_css est résolu depuis docs_dir (= features/)

# ── Créer l'arborescence ───────────────────────────────────────────────────

mkdir -p \
  "${FEATURE_DIR}/spec/schemas" \
  "${FEATURE_DIR}/plan" \
  "${FEATURE_DIR}/tasks" \
  "${FEATURE_DIR}/validation" \
  "${FEATURE_DIR}/docs" \
  "${ASSETS_DIR}"

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

# ── Copier les assets CSS ──────────────────────────────────────────────────

cp "${FRAMEWORK_DIR}/templates/feature-web/extra.css" "${ASSETS_DIR}/extra.css" 2>/dev/null || true

# ── mkdocs.yml projet ─────────────────────────────────────────────────────
# Config dans un dossier voisin de features/ : mkdocs refuse un docs_dir parent
# du fichier de config (et un site_dir inclus dans docs_dir).

WEB_DIR="${PROJECT_ROOT}/.claude/features-web"
MKDOCS_YML="${WEB_DIR}/mkdocs.yml"
mkdir -p "${WEB_DIR}"

if [[ ! -f "${MKDOCS_YML}" ]]; then
  sed \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    -e "s|{{FEATURES_PATH}}|${FEATURES_DIR}|g" \
    -e "s|{{SITE_PATH}}|${WEB_DIR}/.site|g" \
    "${FRAMEWORK_DIR}/templates/feature-web/mkdocs.yml.template" \
    > "${MKDOCS_YML}"
  echo "[feature-init] mkdocs.yml créé : ${MKDOCS_YML}"
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
echo "[feature-init] Démarrer l'interface web : feature-serve"
