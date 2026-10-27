#!/usr/bin/env bash
# feature-hub.sh — Registre des projets /feature et génération du hub MkDocs unique
#
# Usage:
#   feature-hub.sh register <project-name> [project-root]   Inscrit un projet (root : repo git courant)
#   feature-hub.sh unregister <project-name>                 Retire un projet du registre
#   feature-hub.sh list                                      Liste les projets inscrits
#   feature-hub.sh name-of <project-root>                    Nom sous lequel la racine est inscrite
#   feature-hub.sh validate <project-name>                   Vérifie qu'un nom est utilisable
#   feature-hub.sh build                                     (Re)génère le hub (mkdocs.yml, liens, accueil)
#
# Un projet est identifié par sa racine : une racine déjà inscrite garde son nom,
# et un nom déjà pris par une autre racine est refusé.
#
# Le hub vit dans ${FEATURES_HUB_DIR:-~/.claude/features-hub} :
#   registry.json   {"projects": {"<nom>": "<racine du projet>"}}  — seule donnée persistante
#   mkdocs.yml      généré depuis templates/feature-web/mkdocs.yml.template
#   docs/<nom>      lien vers <racine>/.claude/features (un onglet par projet)
#   pages de suivi  générées au build par templates/feature-web/kanban_hook.py
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
HUB_DIR="${FEATURES_HUB_DIR:-${HOME}/.claude/features-hub}"
REGISTRY="${HUB_DIR}/registry.json"
DOCS_DIR="${HUB_DIR}/docs"

die() { echo "[feature-hub] $*" >&2; exit 1; }
log() { echo "[feature-hub] $*"; }

ensure_registry() {
  command -v jq &>/dev/null || die "jq requis."
  mkdir -p "${HUB_DIR}"
  [[ -f "${REGISTRY}" ]] || echo '{"projects": {}}' > "${REGISTRY}"
  jq empty "${REGISTRY}" 2>/dev/null || die "JSON invalide : ${REGISTRY}"
}

# Le nom devient un dossier du site et une clé YAML du .pages : liste blanche,
# sans les noms déjà utilisés par le hub ou par la sortie de mkdocs.
validate_name() {
  local name="$1"
  [[ "${name}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
    || die "Nom de projet invalide : '${name}' (lettres, chiffres, . _ -)"
  case "${name}" in
    assets|index.md|en-cours.md|search|en-cours|404.html|sitemap.xml|sitemap.xml.gz)
      die "Nom de projet réservé : '${name}'" ;;
  esac
}

write_registry() {
  local tmp
  tmp="$(mktemp "${HUB_DIR}/.registry.XXXXXX")"
  jq "$@" "${REGISTRY}" > "${tmp}" && mv "${tmp}" "${REGISTRY}"
}

cmd_register() {
  local name="${1:?Usage: feature-hub.sh register <project-name> [project-root]}"
  local root="${2:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  validate_name "${name}"
  # Chemin physique : c'est ce que renvoie git rev-parse --show-toplevel.
  root="$(cd "${root}" && pwd -P)" || die "Racine introuvable : ${root}"
  ensure_registry

  local existing_name current
  existing_name="$(cmd_name_of "${root}")"
  if [[ -n "${existing_name}" ]]; then
    [[ "${existing_name}" == "${name}" ]] \
      || log "${root} est déjà inscrit sous '${existing_name}' : nom conservé"
    return 0
  fi
  # shellcheck disable=SC2016  # $variables jq, pas shell
  current="$(jq -r --arg n "${name}" '.projects[$n] // empty' "${REGISTRY}")"
  if [[ -n "${current}" ]]; then
    die "Nom '${name}' déjà pris par ${current}. Choisir un autre nom, ou : feature-hub.sh unregister ${name}"
  fi
  # shellcheck disable=SC2016  # $variables jq, pas shell
  write_registry --arg n "${name}" --arg r "${root}" '.projects[$n] = $r'
  log "Projet '${name}' inscrit (${root})"
}

cmd_unregister() {
  local name="${1:?Usage: feature-hub.sh unregister <project-name>}"
  ensure_registry
  # shellcheck disable=SC2016  # $variables jq, pas shell
  jq -e --arg n "${name}" '.projects | has($n)' "${REGISTRY}" >/dev/null \
    || die "Projet '${name}' non inscrit"
  # shellcheck disable=SC2016  # $variables jq, pas shell
  write_registry --arg n "${name}" 'del(.projects[$n])'
  log "Projet '${name}' retiré du registre (ses fichiers ne sont pas touchés)"
}

cmd_name_of() {
  local root="${1:?Usage: feature-hub.sh name-of <project-root>}"
  ensure_registry
  # shellcheck disable=SC2016  # $variables jq, pas shell
  jq -r --arg r "${root}" \
    'first(.projects | to_entries[] | select(.value == $r) | .key) // empty' "${REGISTRY}"
}

cmd_list() {
  ensure_registry
  jq -r '.projects | to_entries[] | "\(.key)\t\(.value)"' "${REGISTRY}"
}

# Projets dont le dossier de features existe encore : "<nom>\t<dossier features>"
active_projects() {
  local name root
  while IFS=$'\t' read -r name root; do
    [[ -n "${name}" ]] || continue
    if ! (validate_name "${name}") 2>/dev/null; then
      log "ignoré : nom invalide '${name}' dans ${REGISTRY}" >&2
    elif [[ -d "${root}/.claude/features" ]]; then
      printf '%s\t%s\n' "${name}" "${root}/.claude/features"
    else
      log "ignoré : '${name}' n'a pas de features (${root}/.claude/features absent)" >&2
    fi
  done < <(cmd_list)
}

# Onglets : accueil d'abord, puis les projets sous leur nom exact
# (awesome-pages réécrirait sinon « antares_ai » en « Antares ai »).
write_nav() {
  local projects="$1" name dir
  {
    echo "nav:"
    echo "  - index.md"
    echo "  - en-cours.md"
    while IFS=$'\t' read -r name dir; do
      [[ -n "${name}" ]] || continue
      printf '  - "%s": "%s"\n' "${name}" "${name}"
    done < <(sort <<< "${projects}")
  } > "${DOCS_DIR}/.pages"
}

cmd_build() {
  ensure_registry
  mkdir -p "${DOCS_DIR}/assets"

  # Seuls les liens sont supprimés : docs/ ne contient rien d'autre de persistant.
  find "${DOCS_DIR}" -mindepth 1 -maxdepth 1 -type l -delete

  local projects="" name dir
  while IFS=$'\t' read -r name dir; do
    [[ -n "${name}" ]] || continue
    if [[ -e "${DOCS_DIR}/${name}" ]]; then
      log "ignoré : '${name}' (${DOCS_DIR}/${name} existe et n'est pas un lien)" >&2
      continue
    fi
    ln -s "${dir}" "${DOCS_DIR}/${name}"
    projects+="${name}"$'\t'"${dir}"$'\n'
  done < <(active_projects)

  cp "${FRAMEWORK_DIR}/templates/feature-web/extra.css" "${DOCS_DIR}/assets/extra.css"
  # Accueil, « En ce moment » et kanbans : générés par le hook MkDocs (kanban_hook.py).
  rm -f "${DOCS_DIR}/index.md"
  write_nav "${projects}"

  sed \
    -e "s|{{DOCS_PATH}}|${DOCS_DIR}|g" \
    -e "s|{{SITE_PATH}}|${HUB_DIR}/.site|g" \
    -e "s|{{HOOKS_PATH}}|${FRAMEWORK_DIR}/templates/feature-web/kanban_hook.py|g" \
    "${FRAMEWORK_DIR}/templates/feature-web/mkdocs.yml.template" \
    > "${HUB_DIR}/mkdocs.yml"

  log "Hub généré : ${HUB_DIR} ($(grep -c . <<< "${projects}" || true) projet(s))"
}

case "${1:-}" in
  register)   shift; cmd_register "$@" ;;
  unregister) shift; cmd_unregister "$@" ;;
  list)       cmd_list ;;
  name-of)    shift; cmd_name_of "$@" ;;
  validate)   shift; validate_name "${1:-}" ;;
  build)      cmd_build ;;
  *)          sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
