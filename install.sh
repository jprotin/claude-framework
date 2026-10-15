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
    skills
    commands
    agents
    hooks
    templates
    bin
    docs
)

# settings.json n'est PAS symlinké : il est généré = base du repo + overlay local.
# La clé autoMode n'est lue que depuis ~/.claude/settings.json (ignorée dans les
# settings projet), d'où un overlay non versionné pour la config perso/client.
readonly SETTINGS_BASE="$FRAMEWORK_DIR/settings.json"
readonly SETTINGS_OVERLAY="$CLAUDE_DIR/settings.overlay.json"
readonly SETTINGS_TARGET="$CLAUDE_DIR/settings.json"

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

settings.json est généré (pas symlinké) : fusion de la base du repo et de
l'overlay local non versionné ~/.claude/settings.overlay.json (s'il existe).
Objets fusionnés en profondeur, tableaux concaténés (sans doublons), l'overlay
gagne sur les scalaires. Relancer ce script après toute modif de l'un des deux.

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

command -v jq >/dev/null 2>&1 || die "jq requis pour générer settings.json"
jq empty "$SETTINGS_BASE" || die "JSON invalide: $SETTINGS_BASE"
if [[ -e "$SETTINGS_OVERLAY" ]]; then
    jq empty "$SETTINGS_OVERLAY" || die "JSON invalide: $SETTINGS_OVERLAY"
fi

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

# -------- Générer settings.json (base + overlay) --------
info "Génération de settings.json"
overlay_src="$SETTINGS_OVERLAY"
[[ -e "$overlay_src" ]] || overlay_src=/dev/null

generated="$(mktemp)"
trap 'rm -f "$generated"' EXIT
# shellcheck disable=SC2016  # $variables jq, pas shell
jq -n --slurpfile base "$SETTINGS_BASE" --slurpfile overlay "$overlay_src" '
    def merge(a; b):
        if (a | type) == "object" and (b | type) == "object" then
            reduce (b | keys_unsorted[]) as $k (a; .[$k] = merge(a[$k]; b[$k]))
        elif (a | type) == "array" and (b | type) == "array" then
            a + (b - a)
        elif b == null then a
        else b
        end;
    merge($base[0]; $overlay[0] // {})
' > "$generated"

if [[ -L "$SETTINGS_TARGET" ]]; then
    # Ancienne installation : settings.json était un symlink vers le repo
    run rm "$SETTINGS_TARGET"
elif [[ -e "$SETTINGS_TARGET" ]] && ! cmp -s "$generated" "$SETTINGS_TARGET"; then
    # Contenu divergent (ex. modif via /config) : on garde une copie avant écrasement
    settings_backup="$SETTINGS_TARGET.bak-$(date +%Y%m%d-%H%M%S)"
    warn "settings.json diffère du résultat généré, backup vers $settings_backup"
    warn "Reporter dans $SETTINGS_OVERLAY toute modif locale à conserver."
    run cp -p "$SETTINGS_TARGET" "$settings_backup"
fi

if [[ -e "$SETTINGS_TARGET" ]] && cmp -s "$generated" "$SETTINGS_TARGET"; then
    ok "settings.json (à jour)"
else
    run install -m 600 "$generated" "$SETTINGS_TARGET"
    if [[ "$overlay_src" == /dev/null ]]; then
        add "settings.json (base seule, pas d'overlay)"
    else
        add "settings.json (base + overlay)"
    fi
fi

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
