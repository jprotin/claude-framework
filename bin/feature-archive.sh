#!/usr/bin/env bash
# feature-archive.sh — Archive centrale des artéfacts /feature (repo git privé, un dossier par projet)
#
# Usage:
#   feature-archive.sh init      Crée le dépôt local et son remote (n'appelle pas le réseau)
#   feature-archive.sh sync [projet]  Copie les features des projets « archive = on »
#                                     (ou du seul projet donné), puis git add
#   feature-archive.sh status    Ce qui serait commité (lecture seule)
#   feature-archive.sh commit    Recherche de secrets (gitleaks) puis commit local (jamais de push)
#
# Seuls les projets autorisés sont copiés : feature-hub.sh option <projet> archive on.
# Le push reste manuel : git -C ~/.claude/features-archive push. Vérifier avant le premier
# envoi que le repo distant est bien privé.
#
# Variables : FEATURES_ARCHIVE_DIR (défaut ~/.claude/features-archive),
#             FEATURES_ARCHIVE_REMOTE (défaut https://github.com/jprotin/claude-features.git)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_DIR="${FEATURES_ARCHIVE_DIR:-${HOME}/.claude/features-archive}"
REMOTE="${FEATURES_ARCHIVE_REMOTE:-https://github.com/jprotin/claude-features.git}"
HUB="${SCRIPT_DIR}/feature-hub.sh"

die() { echo "[feature-archive] $*" >&2; exit 1; }
log() { echo "[feature-archive] $*"; }

require_archive() {
  [[ -d "${ARCHIVE_DIR}/.git" ]] || die "Archive absente : lancer d'abord feature-archive.sh init"
}

cmd_init() {
  if [[ -d "${ARCHIVE_DIR}/.git" ]]; then
    log "Archive déjà initialisée : ${ARCHIVE_DIR}"
    return 0
  fi
  [[ ! -e "${ARCHIVE_DIR}" ]] || die "${ARCHIVE_DIR} existe et n'est pas un dépôt git"
  git init -q -b main "${ARCHIVE_DIR}"
  git -C "${ARCHIVE_DIR}" remote add origin "${REMOTE}"
  cat > "${ARCHIVE_DIR}/README.md" <<'EOF'
# Archive des features

Copie des artéfacts du pipeline `/feature` (spec, plan, tâches, validation, documentation),
un dossier par projet. Alimentée par `feature-archive.sh sync` depuis le framework Claude Code ;
ne pas éditer ici : les modifications seraient écrasées à la synchronisation suivante.
EOF
  printf '%s\n' '.feature-tasks.lock' '.*.json.*' > "${ARCHIVE_DIR}/.gitignore"
  log "Archive créée : ${ARCHIVE_DIR} (remote ${REMOTE})"
  log "Si le repo GitHub n'est pas vide : git -C ${ARCHIVE_DIR} pull origin main --allow-unrelated-histories"
}

# Cible de rsync --delete : forcément un sous-dossier direct de l'archive, jamais l'archive
# elle-même ni un parent (un registre édité à la main pourrait contenir « .. »).
archive_target() {
  local name="$1" target
  bash "${HUB}" validate "${name}" 2>/dev/null || return 1
  target="$(realpath -m "${ARCHIVE_DIR}/${name}")"
  [[ "$(dirname "${target}")" == "$(realpath "${ARCHIVE_DIR}")" && "${target}" != */.git ]] || return 1
  echo "${target}"
}

cmd_sync() {
  require_archive
  local only="${1:-}" name root target synced=0
  local -a allowed=()
  while IFS=$'\t' read -r name root; do
    [[ -n "${name}" ]] || continue
    [[ "$(bash "${HUB}" option-of "${name}" archive)" == "on" ]] || continue
    if ! target="$(archive_target "${name}")"; then
      log "ignoré : nom de projet invalide '${name}' dans le registre" >&2
      continue
    fi
    allowed+=("${name}")
    [[ -z "${only}" || "${name}" == "${only}" ]] || continue
    if [[ ! -d "${root}/.claude/features" ]]; then
      log "ignoré : '${name}' (${root}/.claude/features absent)"
      continue
    fi
    # --delete limité au dossier du projet : une feature supprimée localement disparaît
    # de la version courante, l'historique git la conserve.
    rsync -a --delete --exclude '.feature-tasks.lock' --exclude '.*.json.*' \
      "${root}/.claude/features/" "${target}/"
    synced=$((synced + 1))
    log "synchronisé : ${name}"
  done < <(bash "${HUB}" list)

  if [[ ${synced} -eq 0 ]]; then
    if [[ -n "${only}" ]]; then
      log "Projet '${only}' non synchronisé : non inscrit, ou archive off (feature-hub.sh options)"
    else
      log "Aucun projet autorisé : feature-hub.sh option <projet> archive on"
    fi
  fi
  warn_orphans "${allowed[@]}"
  git -C "${ARCHIVE_DIR}" add -A
  cmd_status
}

# Dossiers de projets qui ne sont plus autorisés : signalés, jamais supprimés automatiquement
# (retirer l'accord d'un client doit être une action explicite).
warn_orphans() {
  local dir name known
  for dir in "${ARCHIVE_DIR}"/*/; do
    [[ -d "${dir}" ]] || continue
    name="$(basename "${dir}")"
    for known in "$@"; do
      [[ "${name}" == "${known}" ]] && continue 2
    done
    log "ATTENTION : '${name}' est dans l'archive mais n'est plus autorisé (archive off ou désinscrit)."
    log "  Pour le retirer de la version courante : git -C ${ARCHIVE_DIR} rm -r -q ${name}, puis commit"
  done
}

cmd_status() {
  require_archive
  local changes
  changes="$(git -C "${ARCHIVE_DIR}" status --porcelain)"
  if [[ -z "${changes}" ]]; then
    log "Rien à commiter."
    return 0
  fi
  log "Fichiers modifiés, par dossier :"
  cut -c4- <<< "${changes}" | cut -d/ -f1 | sort | uniq -c
  log "Pour enregistrer : feature-archive.sh commit, puis git -C ${ARCHIVE_DIR} push"
}

cmd_commit() {
  require_archive
  git -C "${ARCHIVE_DIR}" add -A
  if git -C "${ARCHIVE_DIR}" diff --cached --quiet; then
    log "Rien à commiter."
    return 0
  fi
  if command -v gitleaks &>/dev/null; then
    gitleaks git --staged --no-banner --redact "${ARCHIVE_DIR}" \
      || die "Secret détecté dans les fichiers à commiter : corriger l'artéfact source, puis sync"
  else
    log "ATTENTION : gitleaks absent, commit sans recherche de secrets"
  fi
  local projects
  projects="$(git -C "${ARCHIVE_DIR}" diff --cached --name-only | grep / | cut -d/ -f1 | sort -u \
    | paste -sd, - || true)"
  git -C "${ARCHIVE_DIR}" commit -q \
    -m "Synchronisation du $(date +'%Y-%m-%d %H:%M')${projects:+ : ${projects}}"
  git -C "${ARCHIVE_DIR}" log --oneline -1
  log "Commit local fait. Push manuel : git -C ${ARCHIVE_DIR} push -u origin main"
}

case "${1:-}" in
  init)   cmd_init ;;
  sync)   shift; cmd_sync "$@" ;;
  status) cmd_status ;;
  commit) cmd_commit ;;
  *)      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
