#!/usr/bin/env bash
# feature-serve.sh — Démarre l'interface web MkDocs pour les features du projet courant
# Usage: feature-serve [port]
set -euo pipefail

PORT="${1:-8888}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FEATURES_DIR="${PROJECT_ROOT}/.claude/features"
MKDOCS_YML="${PROJECT_ROOT}/.claude/features-web/mkdocs.yml"

# ── Vérifications ──────────────────────────────────────────────────────────

if [[ ! -d "${FEATURES_DIR}" ]]; then
  echo "Aucune feature initialisée. Lance d'abord /feature pour créer une feature."
  exit 1
fi

if [[ ! -f "${MKDOCS_YML}" ]]; then
  echo "${MKDOCS_YML} introuvable. Relance /feature (feature-init) pour le générer."
  exit 1
fi

# ── Vérifier mkdocs + thème material + plugin awesome-pages ──────────────
# Pas d'installation ici : elle passe par claude-install-prereqs.sh (venv pipx isolé).
# Les modules sont cherchés avec le Python de l'environnement qui fournit 'mkdocs'
# ('pip show' interrogerait le pip courant, pas le venv pipx).

readonly INSTALL_HINT="Installer : ~/.claude/bin/claude-install-prereqs.sh --groups agentic"

if ! command -v mkdocs &>/dev/null; then
  echo "mkdocs introuvable. ${INSTALL_HINT}"
  exit 1
fi

MKDOCS_PYTHON="$(head -1 "$(readlink -f "$(command -v mkdocs)")" | sed 's/^#!//')"
has_module() { "${MKDOCS_PYTHON}" -c "import $1" &>/dev/null; }

if ! has_module material; then
  echo "Thème mkdocs-material absent de l'environnement de mkdocs. ${INSTALL_HINT}"
  exit 1
fi

# ── Mettre à jour mkdocs.yml si awesome-pages disponible ─────────────────

if ! grep -q "awesome-pages" "${MKDOCS_YML}" 2>/dev/null; then
  if has_module mkdocs_awesome_pages_plugin; then
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
