#!/usr/bin/env bash
#
# claude-init-project.sh — Initialise un projet avec le stack standard Claude Code.
#
# Usage: claude-init-project.sh [--force] [--no-git-flow] [--no-pre-commit]
#
# Installe : .editorconfig, .gitignore, .pre-commit-config.yaml, .yamllint,
#            CLAUDE.md (template), structure docs/, init GitFlow.
#
# Les configs Claude (CLAUDE.md + .claude/) sont AUTOMATIQUEMENT gitignorées.

set -euo pipefail
IFS=$'\n\t'

readonly TEMPLATES_DIR="$HOME/.claude/templates"
readonly SCRIPT_NAME="${0##*/}"
readonly PREREQS_SCRIPT="$HOME/.claude/bin/claude-install-prereqs.sh"

force=0
init_git_flow=1
init_pre_commit=1
install_prereqs=0
install_prereqs_interactive=0

log()   { echo "[$(date +'%H:%M:%S')] $*" >&2; }
info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*"; }
die()   { error "$*"; exit 1; }

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Options:
  -h, --help                          Affiche cette aide
  -f, --force                         Écrase les fichiers existants sans confirmer
  --no-git-flow                       Ne pas initialiser GitFlow
  --no-pre-commit                     Ne pas installer les hooks pre-commit
  --install-prereqs                   Installe les prérequis outils (tout)
  --install-prereqs-interactive       Installe les prérequis (mode interactif)

Ce script initialise le projet courant avec :
  - .editorconfig, .gitignore, .pre-commit-config.yaml, .yamllint
  - CLAUDE.md (template — à compléter)
  - Structure docs/adr, docs/runbooks
  - Branches main + develop (via GitFlow si disponible)
  - Hooks pre-commit installés

Les fichiers CLAUDE.md et .claude/ sont AUTOMATIQUEMENT gitignorés.
EOF
}

confirm() {
    local prompt="${1:-Continuer ?}"
    [[ $force -eq 1 ]] && return 0
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)                      usage; exit 0 ;;
        -f|--force)                     force=1; shift ;;
        --no-git-flow)                  init_git_flow=0; shift ;;
        --no-pre-commit)                init_pre_commit=0; shift ;;
        --install-prereqs)              install_prereqs=1; shift ;;
        --install-prereqs-interactive)  install_prereqs_interactive=1; shift ;;
        *)                              die "Option inconnue: $1" ;;
    esac
done

# -------- Installation prérequis (si demandée) --------
if [[ $install_prereqs -eq 1 ]] || [[ $install_prereqs_interactive -eq 1 ]]; then
    [[ -x "$PREREQS_SCRIPT" ]] || die "Script prérequis introuvable: $PREREQS_SCRIPT"
    info "Lancement de l'installation des prérequis"
    if [[ $install_prereqs_interactive -eq 1 ]]; then
        "$PREREQS_SCRIPT" --interactive
    else
        "$PREREQS_SCRIPT" --all
    fi
    echo
fi

[[ -d "$TEMPLATES_DIR" ]] || die "Templates introuvables : $TEMPLATES_DIR"

info "Init dans: $(pwd)"

# ----- 1. Git init si nécessaire -----
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    info "Initialisation du repo git"
    git init -b main
else
    info "Repo git déjà initialisé"
fi

# Garantir au moins un commit (HEAD non-né → git branch/flow échoue sinon).
# Vaut aussi pour un repo déjà init'é mais sans commit.
if ! git rev-parse --verify -q HEAD >/dev/null 2>&1; then
    info "Aucun commit présent : création du commit initial"
    git commit --allow-empty -m "chore: initial commit" >/dev/null
fi

current_branch=$(git branch --show-current)
info "Branche courante: $current_branch"

# ----- 2. Copier les fichiers de config -----
install_file() {
    local src="$1"
    local dst="$2"
    if [[ -f "$dst" ]]; then
        if [[ $force -eq 0 ]]; then
            warn "Existe déjà, conservé: $dst"
            return
        fi
        info "Écrasement (--force): $dst"
    fi
    cp "$src" "$dst"
    info "Installé: $dst"
}

install_file "$TEMPLATES_DIR/.editorconfig"          ".editorconfig"
install_file "$TEMPLATES_DIR/.pre-commit-config.yaml" ".pre-commit-config.yaml"
install_file "$TEMPLATES_DIR/.yamllint"              ".yamllint"

# ----- 3. .gitignore (fusion, pas écrasement) -----
gitignore_claude_lines="# ===== Claude Code (config privée, ne pas versionner) =====
CLAUDE.md
.claude/
.claude-local/"

if [[ -f .gitignore ]]; then
    if ! grep -q "^CLAUDE.md$" .gitignore 2>/dev/null; then
        info ".gitignore existant : ajout des lignes Claude en tête"
        printf '%s\n\n%s' "$gitignore_claude_lines" "$(cat .gitignore)" > .gitignore.tmp
        mv .gitignore.tmp .gitignore
    else
        info ".gitignore : lignes Claude déjà présentes"
    fi
    # Ajouter les autres sections du template si pas présentes
    # (simpliste : concat, dédup minimale via user)
    if ! grep -q "^node_modules/$" .gitignore; then
        info "Ajout des sections standards au .gitignore (langages courants)"
        cat "$TEMPLATES_DIR/.gitignore" | grep -vE '^# ===== Claude' | grep -v "^CLAUDE.md$" | grep -v "^\.claude/$" | grep -v "^\.claude-local/$" >> .gitignore
    fi
else
    cp "$TEMPLATES_DIR/.gitignore" .gitignore
    info "Installé: .gitignore"
fi

# ----- 4. CLAUDE.md projet -----
if [[ -f CLAUDE.md ]]; then
    warn "CLAUDE.md existant, conservé"
else
    project_name="$(basename "$(pwd)")"
    sed "s/{{PROJECT_NAME}}/$project_name/g" "$TEMPLATES_DIR/CLAUDE.md.template" > CLAUDE.md
    info "Installé: CLAUDE.md (à compléter)"
fi

# ----- 5. Structure docs -----
mkdir -p docs/adr docs/runbooks
[[ -f docs/adr/.gitkeep ]] || touch docs/adr/.gitkeep
[[ -f docs/runbooks/.gitkeep ]] || touch docs/runbooks/.gitkeep
info "Structure docs/ créée"

# ----- 6. GitFlow -----
if [[ $init_git_flow -eq 1 ]]; then
    # S'assurer que 'develop' existe (prérequis pour activer gitflow-guard.sh)
    if git show-ref --verify --quiet refs/heads/develop; then
        info "Branche develop déjà présente"
    else
        # git-flow init refuse un working tree sale — fallback vers git branch (non destructif)
        if command -v git-flow >/dev/null 2>&1 && git diff-index --quiet HEAD -- 2>/dev/null && git diff-index --quiet --cached HEAD -- 2>/dev/null; then
            info "Init GitFlow via git-flow CLI"
            git flow init -d >/dev/null 2>&1 || git branch develop
        else
            info "Création de la branche develop (git branch, non destructif)"
            git branch develop
        fi
    fi
fi

# ----- 6bis. Baseline detect-secrets (requise par le hook detect-secrets) -----
if command -v detect-secrets >/dev/null 2>&1; then
    if [[ -f .secrets.baseline ]]; then
        info "Baseline detect-secrets déjà présente"
    else
        info "Génération de la baseline detect-secrets (.secrets.baseline)"
        detect-secrets scan > .secrets.baseline
    fi
else
    warn "detect-secrets non installé — baseline non générée (le hook detect-secrets échouera)"
    warn "Installe-le puis lance : detect-secrets scan > .secrets.baseline"
fi

# ----- 7. Pre-commit install -----
if [[ $init_pre_commit -eq 1 ]]; then
    if command -v pre-commit >/dev/null 2>&1; then
        info "Installation des hooks pre-commit"
        pre-commit install >/dev/null 2>&1 && info "Hook pre-commit installé" || warn "Hook pre-commit : erreur"
        pre-commit install --hook-type commit-msg >/dev/null 2>&1 || true
    else
        warn "pre-commit non installé — lance: $PREREQS_SCRIPT --groups core"
    fi
fi

# ----- 7bis. Check des prérequis transverses (avertissement uniquement) -----
check_prereqs() {
    local -a missing=()
    local -a expected=(jq shellcheck shfmt yamllint git-flow pre-commit gitleaks detect-secrets)
    for t in "${expected[@]}"; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo
        warn "Outils manquants (non bloquants) : ${missing[*]}"
        warn "Installation : $PREREQS_SCRIPT"
        warn "Audit complet : $PREREQS_SCRIPT --check"
    fi
}
check_prereqs

# ----- 8. Résumé -----
cat <<EOF

================================================================
✅ Bootstrap terminé pour: $(pwd)
================================================================

Fichiers installés:
  - .editorconfig
  - .gitignore (avec exclusion CLAUDE.md / .claude/)
  - .pre-commit-config.yaml
  - .yamllint
  - CLAUDE.md (à compléter)
  - docs/adr/, docs/runbooks/

Prochaines étapes:
  1. Compléter CLAUDE.md (contexte projet)
  2. pre-commit run --all-files   # valider la base
  3. Installer les deps de ton stack (pnpm install / composer install / pip install -e .[dev])
  4. git status && git add . && git commit -m "chore: bootstrap tooling"

Gestion des outils prérequis:
  ~/.claude/bin/claude-install-prereqs.sh --check          # audit
  ~/.claude/bin/claude-install-prereqs.sh                  # installer tout
  ~/.claude/bin/claude-install-prereqs.sh --interactive    # choix à la carte
  ~/.claude/bin/claude-install-prereqs.sh --upgrade        # forcer upgrade

Règles GitFlow à respecter:
  - Pas de commit sur main/develop directement
  - feature/* depuis develop
  - hotfix/*  depuis main
  - release/* depuis develop (double merge + tag)

Skills disponibles: /architect, /sre, /devops, /security, /terraform,
  /ansible, /kubernetes, /docker, /python, /bash, /javascript, /typescript,
  /php, /analyze, /review, /debug, /gitflow, /commit, /adr,
  /save-context, /load-context, /onboard-project, /skill-enrich

Voir ~/.claude/CLAUDE.md pour le workflow complet.

EOF
