#!/usr/bin/env bash
#
# install.sh — Installe le framework Claude Code en créant les symlinks depuis ~/.claude/
#              vers ce repo.
#
# À lancer après `git clone` sur une nouvelle machine.
# Sauvegarde automatiquement un ~/.claude/ existant.

set -euo pipefail
IFS=$'\n\t'

readonly FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLAUDE_DIR="$HOME/.claude"
readonly SCRIPT_NAME="${0##*/}"

# Items à symlinker (fichiers et dossiers)
readonly LINK_ITEMS=(
    CLAUDE.md
    RTK.md
    GITFLOW.md
    CODING_STANDARDS.md
    settings.json
    skills
    commands
    agents
    hooks
    templates
    bin
    docs
)

log()   { printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"; }
info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*" >&2; }
die()   { error "$*"; exit 1; }
ok()    { printf '  ✓  %s\n' "$*"; }
add()   { printf '  +  %s\n' "$*"; }

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Installe le framework Claude Code en créant les symlinks ~/.claude/<item>
pointant vers ce repo ($FRAMEWORK_DIR).

Options:
  -h, --help        Aide
  --dry-run         Affiche ce qui serait fait sans rien modifier
  --force           Écrase sans backup les liens/fichiers existants dans ~/.claude/

Items symlinkés:
  ${LINK_ITEMS[@]}

Les dossiers runtime de Claude Code (projects/, sessions/, cache/, ...) ne sont
PAS touchés — ils restent dans ~/.claude/ comme dossiers réels.

EOF
}

dry_run=0
force=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --dry-run) dry_run=1; shift ;;
        --force)   force=1; shift ;;
        *)         die "Option inconnue: $1" ;;
    esac
done

run() {
    if [[ $dry_run -eq 1 ]]; then
        printf '  [DRY-RUN] %s\n' "$*"
        return 0
    fi
    "$@"
}

# -------- Vérifications --------
info "Framework dir: $FRAMEWORK_DIR"
info "Claude dir:    $CLAUDE_DIR"

for item in "${LINK_ITEMS[@]}"; do
    [[ -e "$FRAMEWORK_DIR/$item" ]] || die "Manquant dans le framework: $item"
done

# -------- Préparer ~/.claude/ --------
if [[ ! -d "$CLAUDE_DIR" ]]; then
    info "Création de $CLAUDE_DIR"
    run mkdir -p "$CLAUDE_DIR"
fi

# -------- Backup si contenu existant et pas --force --------
needs_backup=0
for item in "${LINK_ITEMS[@]}"; do
    target="$CLAUDE_DIR/$item"
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        needs_backup=1
        break
    fi
    # Symlink existant pointant vers autre chose
    if [[ -L "$target" ]]; then
        current="$(readlink "$target")"
        expected="$FRAMEWORK_DIR/$item"
        if [[ "$current" != "$expected" ]]; then
            needs_backup=1
            break
        fi
    fi
done

if [[ $needs_backup -eq 1 ]] && [[ $force -eq 0 ]]; then
    backup_dir="$HOME/.claude.bak-$(date +%Y%m%d-%H%M%S)"
    info "Backup des items conflictuels vers $backup_dir"
    run mkdir -p "$backup_dir"
    for item in "${LINK_ITEMS[@]}"; do
        target="$CLAUDE_DIR/$item"
        if [[ -e "$target" ]]; then
            if [[ -L "$target" ]]; then
                current="$(readlink "$target")"
                expected="$FRAMEWORK_DIR/$item"
                [[ "$current" == "$expected" ]] && continue
            fi
            run mv "$target" "$backup_dir/"
        fi
    done
fi

# -------- Créer les symlinks --------
info "Création des symlinks"
for item in "${LINK_ITEMS[@]}"; do
    src="$FRAMEWORK_DIR/$item"
    dst="$CLAUDE_DIR/$item"

    if [[ -L "$dst" ]]; then
        current="$(readlink "$dst")"
        if [[ "$current" == "$src" ]]; then
            ok "$item (déjà lié)"
            continue
        fi
        if [[ $force -eq 1 ]]; then
            run rm "$dst"
        else
            die "Symlink existant mais différent: $dst → $current (attendu: $src). Utilise --force."
        fi
    elif [[ -e "$dst" ]]; then
        if [[ $force -eq 1 ]]; then
            run rm -rf "$dst"
        else
            die "Fichier/dossier existant: $dst. Utilise --force pour écraser (backup fait)."
        fi
    fi

    run ln -s "$src" "$dst"
    add "$item"
done

# -------- Résumé --------
cat <<EOF

================================================================
✅ Installation du framework terminée

Framework : $FRAMEWORK_DIR
Liens     : $CLAUDE_DIR/

Vérification : ls -la $CLAUDE_DIR/ | grep '\->'

Prochaines étapes :
  1. Installer les outils prérequis :
     $CLAUDE_DIR/bin/claude-install-prereqs.sh --check
     $CLAUDE_DIR/bin/claude-install-prereqs.sh

  2. Vérifier \$PATH contient \$HOME/.local/bin (pour binaires GitHub) :
     echo \$PATH | tr ':' '\n' | grep '.local/bin' || \
     echo 'export PATH="\$HOME/.local/bin:\$PATH"' >> ~/.bashrc

  3. Bootstraper un projet :
     cd /chemin/projet && \$CLAUDE_DIR/bin/claude-init-project.sh

================================================================

EOF
