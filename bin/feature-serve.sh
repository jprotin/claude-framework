#!/usr/bin/env bash
# feature-serve.sh — Démarre l'interface web MkDocs pour les features du projet courant
# Usage: feature-serve [port]
set -euo pipefail

PORT="${1:-8888}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FEATURES_DIR="${PROJECT_ROOT}/.claude/features"
MKDOCS_YML="${FEATURES_DIR}/mkdocs.yml"

# ── Vérifications ──────────────────────────────────────────────────────────

if [[ ! -d "${FEATURES_DIR}" ]]; then
  echo "Aucune feature initialisée. Lance d'abord /feature pour créer une feature."
  exit 1
fi

if [[ ! -f "${MKDOCS_YML}" ]]; then
  echo "mkdocs.yml introuvable. Lance feature-init pour régénérer."
  exit 1
fi

# ── Vérifier / installer mkdocs-material ──────────────────────────────────

if ! command -v mkdocs &>/dev/null; then
  echo "Installation de mkdocs-material..."
  pip install mkdocs-material mkdocs-awesome-pages-plugin --quiet
fi

# Vérifier awesome-pages plugin
if ! pip show mkdocs-awesome-pages-plugin &>/dev/null; then
  echo "Installation de mkdocs-awesome-pages-plugin..."
  pip install mkdocs-awesome-pages-plugin --quiet
fi

# ── Mettre à jour mkdocs.yml si awesome-pages disponible ─────────────────

if ! grep -q "awesome-pages" "${MKDOCS_YML}" 2>/dev/null; then
  if pip show mkdocs-awesome-pages-plugin &>/dev/null; then
    # Insérer awesome-pages dans les plugins
    sed -i 's/^plugins:$/plugins:\n  - awesome-pages/' "${MKDOCS_YML}"
  fi
fi

# ── Lancer le serveur ─────────────────────────────────────────────────────

echo ""
echo "Interface web features : http://localhost:${PORT}"
echo "Hot-reload actif — les documents générés par le pipeline s'affichent en temps réel."
echo "Ctrl+C pour arrêter."
echo ""

cd "${FEATURES_DIR}" && mkdocs serve \
  --config-file "${MKDOCS_YML}" \
  --dev-addr "127.0.0.1:${PORT}" \
  --watch "${FEATURES_DIR}"
