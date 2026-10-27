#!/usr/bin/env bash
# feature-serve.sh — Démarre l'interface web MkDocs unique pour les features de tous les projets
# Usage: feature-serve [port]
set -euo pipefail

PORT="${1:-8888}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="${FEATURES_HUB_DIR:-${HOME}/.claude/features-hub}"
MKDOCS_YML="${HUB_DIR}/mkdocs.yml"

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

for module in material mkdocs_awesome_pages_plugin; do
  if ! has_module "${module}"; then
    echo "Module ${module} absent de l'environnement de mkdocs. ${INSTALL_HINT}"
    exit 1
  fi
done

# ── Port libre ? (ancien feature-serve par projet encore lancé, typiquement) ─

if command -v ss &>/dev/null && ss -ltnH "sport = :${PORT}" | grep -q .; then
  echo "Le port ${PORT} est déjà utilisé :"
  ss -ltnpH "sport = :${PORT}" 2>/dev/null | sed 's/^/  /'
  echo "Arrêter ce processus, ou choisir un autre port : feature-serve <port>"
  exit 1
fi

# ── Projet courant inscrit au passage (features créées avant le hub) ──────

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
# Non fatal : un nom de dossier déjà pris ou invalide ne doit pas empêcher de servir le hub.
if [[ -n "${PROJECT_ROOT}" && -d "${PROJECT_ROOT}/.claude/features" \
      && -z "$(bash "${SCRIPT_DIR}/feature-hub.sh" name-of "${PROJECT_ROOT}")" ]]; then
  bash "${SCRIPT_DIR}/feature-hub.sh" register "$(basename "${PROJECT_ROOT}")" "${PROJECT_ROOT}" \
    || echo "Projet courant non inscrit : feature-hub.sh register <nom> pour l'ajouter."
fi

bash "${SCRIPT_DIR}/feature-hub.sh" build

# ── Lancer le serveur ─────────────────────────────────────────────────────
# Chaque projet est un lien dans docs/ : on surveille aussi sa cible réelle,
# sinon le hot-reload ne voit pas les fichiers écrits par le pipeline.

watch_args=()
while IFS= read -r link; do
  watch_args+=(--watch "$(readlink -f "${link}")")
done < <(find "${HUB_DIR}/docs" -mindepth 1 -maxdepth 1 -type l)

echo ""
echo "Interface web features (tous projets) : http://localhost:${PORT}"
echo "Hot-reload actif — les documents générés par le pipeline s'affichent en temps réel."
echo "Ctrl+C pour arrêter."
echo ""

cd "${HUB_DIR}" && mkdocs serve \
  --config-file "${MKDOCS_YML}" \
  --dev-addr "127.0.0.1:${PORT}" \
  "${watch_args[@]}"
