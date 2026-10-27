#!/usr/bin/env bash
# feature-promote.sh — Copie les livrables finaux d'une feature dans docs/ du projet (versionnés)
#
# Usage: feature-promote.sh <feature-dir> [--force]
#
#   docs/features/<slug>/README.md  ← docs/feature-doc.md
#   docs/features/<slug>/spec.md    ← spec/analysis-final.md (sinon spec/analysis.md)
#   docs/features/<slug>/plan.md    ← plan/plan-final.md (sinon plan/plan.md)
#
# Les brouillons, challenges, tâches et rapports restent locaux (et dans l'archive centrale).
# Le projet doit l'autoriser : feature-hub.sh option <projet> promote on.
# Un fichier déjà promu qui diffère de l'artéfact n'est remplacé qu'avec --force.
# Rien n'est commité : le script affiche ce qu'il reste à commiter.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_DIR="${1:?Usage: feature-promote.sh <feature-dir> [--force]}"
FORCE="${2:-}"

die() { echo "[feature-promote] $*" >&2; exit 1; }
log() { echo "[feature-promote] $*"; }

[[ -z "${FORCE}" || "${FORCE}" == "--force" ]] || die "Option inconnue : ${FORCE}"
FEATURE_DIR="$(cd "${FEATURE_DIR}" && pwd -P)" || die "Dossier introuvable : $1"
[[ -f "${FEATURE_DIR}/meta.json" ]] || die "${FEATURE_DIR} n'est pas une feature (meta.json absent)"
[[ "$(basename "$(dirname "${FEATURE_DIR}")")" == "features" \
   && "$(basename "$(dirname "$(dirname "${FEATURE_DIR}")")")" == ".claude" ]] \
  || die "Chemin attendu : <projet>/.claude/features/<slug>"

SLUG="$(basename "${FEATURE_DIR}")"
PROJECT_ROOT="$(cd "${FEATURE_DIR}/../../.." && pwd -P)"
PROJECT_NAME="$(bash "${SCRIPT_DIR}/feature-hub.sh" name-of "${PROJECT_ROOT}")"
[[ -n "${PROJECT_NAME}" ]] || die "Projet non inscrit au hub : ${PROJECT_ROOT}"
[[ "$(bash "${SCRIPT_DIR}/feature-hub.sh" option-of "${PROJECT_NAME}" promote)" == "on" ]] \
  || die "Promotion désactivée pour '${PROJECT_NAME}' : feature-hub.sh option ${PROJECT_NAME} promote on"

TARGET_DIR="${PROJECT_ROOT}/docs/features/${SLUG}"

# promote <destination> <source> [<source de repli>]
promote() {
  local destination="${TARGET_DIR}/$1" source=""
  shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "${FEATURE_DIR}/${candidate}" ]]; then
      source="${FEATURE_DIR}/${candidate}"
      break
    fi
  done
  if [[ -z "${source}" ]]; then
    log "absent, ignoré : $*"
    return 0
  fi
  # Un lien symbolique ferait écrire ailleurs que dans le repo.
  [[ ! -L "${destination}" ]] || die "Refus : ${destination} est un lien symbolique"
  if cmp -s "${source}" "${destination}" 2>/dev/null; then
    log "déjà à jour : ${destination#"${PROJECT_ROOT}"/}"
    return 0
  fi
  # Le fichier promu a pu être retouché dans le repo : on ne l'écrase pas sans le demander.
  if [[ -f "${destination}" && "${FORCE}" != "--force" ]]; then
    log "conservé (diffère de l'artéfact, --force pour remplacer) : ${destination#"${PROJECT_ROOT}"/}"
    return 0
  fi
  mkdir -p "${TARGET_DIR}"
  cp "${source}" "${destination}"
  log "promu : ${source#"${FEATURE_DIR}"/} → ${destination#"${PROJECT_ROOT}"/}"

  # Les liens vers les brouillons ou les rapports ne suivent pas : on les signale.
  local broken
  broken="$(grep -oE '\]\(\.\./[^)]*\)' "${destination}" | sort -u | head -5 | sed 's/^/    /' || true)"
  if [[ -n "${broken}" ]]; then
    log "  liens relatifs à vérifier dans $(basename "${destination}") :"
    echo "${broken}"
  fi
}

promote README.md docs/feature-doc.md
promote spec.md spec/analysis-final.md spec/analysis.md
promote plan.md plan/plan-final.md plan/plan.md

if [[ -f "${FEATURE_DIR}/spec/adr-draft.md" ]]; then
  log "Un brouillon d'ADR existe : le formaliser avec /adr dans docs/adr/ (numérotation, statut)."
fi

if git -C "${PROJECT_ROOT}" rev-parse --git-dir &>/dev/null; then
  CHANGES="$(git -C "${PROJECT_ROOT}" status --short -- "docs/features/${SLUG}")"
  if [[ -n "${CHANGES}" ]]; then
    log "À commiter sur la branche de la feature :"
    mapfile -t CHANGED <<< "${CHANGES}"
    printf '    %s\n' "${CHANGED[@]}"
  fi
fi
