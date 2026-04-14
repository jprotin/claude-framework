#!/usr/bin/env bash
#
# claude-install-prereqs.sh — Installe/met à jour les prérequis outils pour le stack Claude Code.
#
# Cible Ubuntu/Debian uniquement.
# Sources : apt (système), pipx (Python), GitHub releases (~/.local/bin).
#
# Usage:
#   claude-install-prereqs.sh                  # tout (défaut)
#   claude-install-prereqs.sh --interactive    # choix à la carte
#   claude-install-prereqs.sh --check          # audit seul
#   claude-install-prereqs.sh --dry-run        # simulation
#   claude-install-prereqs.sh --upgrade        # force upgrade
#   claude-install-prereqs.sh --groups core,terraform
#
# Relancer manuellement quand tu veux mettre à jour.

set -euo pipefail
IFS=$'\n\t'

readonly LOCAL_BIN="$HOME/.local/bin"
readonly SCRIPT_NAME="${0##*/}"
readonly TMP_ROOT="$(mktemp -d -t claude-prereqs.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# -------- Options --------
mode="all"
requested_groups=()
dry_run=0
force_upgrade=0
use_sudo=1
apt_updated=0

# -------- Groupes --------
declare -A GROUP_DESC=(
    [core]="Indispensables (jq, shellcheck, shfmt, yamllint, git-flow, pipx, pre-commit)"
    [secrets]="Détection de secrets (gitleaks, detect-secrets)"
    [python]="Outillage Python (ruff, mypy, black)"
    [terraform]="Terraform + IaC security (terraform, tflint, tfsec, checkov)"
    [docker]="Docker linting (hadolint)"
    [ansible]="Ansible linting (ansible-lint)"
    [sql]="SQL linting (sqlfluff)"
)
readonly GROUPS_ORDER=(core secrets python terraform docker ansible sql)

# -------- Logging --------
info()  { printf '[\e[34mINFO\e[0m]  %s\n' "$*" >&2; }
warn()  { printf '[\e[33mWARN\e[0m]  %s\n' "$*" >&2; }
error() { printf '[\e[31mERROR\e[0m] %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }
ok()    { printf '  \e[32m✓\e[0m  %s\n' "$*"; }
add()   { printf '  \e[36m+\e[0m  %s\n' "$*"; }
upg()   { printf '  \e[35m↑\e[0m  %s\n' "$*"; }
fail()  { printf '  \e[31m✗\e[0m  %s\n' "$*"; }
sk()    { printf '  \e[90m-\e[0m  %s\n' "$*"; }

run() {
    if [[ $dry_run -eq 1 ]]; then
        local IFS=' '
        printf '  [DRY-RUN] %s\n' "$*" >&2
        return 0
    fi
    "$@"
}

# -------- OS detection --------
detect_os() {
    [[ -f /etc/os-release ]] || die "OS non reconnu"
    # shellcheck disable=SC1091
    . /etc/os-release
    local id="${ID:-}" id_like="${ID_LIKE:-}"
    # Direct match
    case "$id" in
        ubuntu|debian)
            info "OS: ${PRETTY_NAME:-$id}"
            return 0
            ;;
    esac
    # Dérivé (ex: TUXEDO OS, Linux Mint, Pop!_OS, Kali...)
    if [[ " $id_like " == *" ubuntu "* ]] || [[ " $id_like " == *" debian "* ]]; then
        info "OS: ${PRETTY_NAME:-$id} (dérivé $id_like)"
        return 0
    fi
    die "OS non supporté: ${id:-?} (Ubuntu/Debian ou dérivé uniquement)"
}

check_local_bin() {
    mkdir -p "$LOCAL_BIN"
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        warn "$LOCAL_BIN n'est pas dans ton \$PATH"
        warn "Ajoute dans ~/.bashrc ou ~/.profile :"
        warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

apt_update_once() {
    [[ $apt_updated -eq 1 ]] && return 0
    [[ $use_sudo -eq 0 ]] && return 0
    [[ $dry_run -eq 1 ]] && { apt_updated=1; return 0; }
    info "apt-get update"
    sudo apt-get update -qq
    apt_updated=1
}

# -------- APT helper --------
apt_ensure() {
    local pkg="$1"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        if [[ $force_upgrade -eq 1 ]]; then
            apt_update_once
            upg "apt: $pkg"
            [[ $use_sudo -eq 1 ]] && run sudo apt-get install -y --only-upgrade "$pkg" >/dev/null || sk "apt: $pkg (no-sudo)"
        else
            ok "apt: $pkg"
        fi
        return 0
    fi
    if [[ $use_sudo -eq 0 ]]; then
        sk "apt: $pkg (no-sudo)"
        return 1
    fi
    apt_update_once
    add "apt: $pkg"
    run sudo apt-get install -y "$pkg" >/dev/null
}

# Tente plusieurs noms de paquet (first found wins)
apt_ensure_any() {
    for pkg in "$@"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            apt_ensure "$pkg"
            return 0
        fi
    done
    apt_update_once
    for pkg in "$@"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            apt_ensure "$pkg"
            return 0
        fi
    done
    fail "Aucun des paquets n'est disponible: $*"
    return 1
}

# -------- pipx helper --------
pipx_ensure() {
    local pkg="$1"
    if ! command -v pipx >/dev/null; then
        fail "pipx manquant — installe d'abord le groupe 'core'"
        return 1
    fi
    if pipx list --short 2>/dev/null | awk '{print $1}' | grep -qx "$pkg"; then
        if [[ $force_upgrade -eq 1 ]]; then
            upg "pipx: $pkg"
            run pipx upgrade "$pkg" >/dev/null
        else
            ok "pipx: $pkg"
        fi
    else
        add "pipx: $pkg"
        run pipx install "$pkg" >/dev/null
    fi
}

# -------- GitHub releases helper --------
github_latest_tag() {
    local repo="$1"
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -Po '"tag_name":\s*"\K[^"]+' \
        | head -1
}

# Install depuis GitHub Releases vers ~/.local/bin
# Args: name, repo, url_template (placeholders {TAG} {VER}), inner_binary_name
github_install() {
    local name="$1" repo="$2" url_tpl="$3" inner="$4"
    local installed_ver=""
    if command -v "$name" >/dev/null 2>&1; then
        installed_ver="$("$name" --version 2>&1 | head -1 \
            | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
    fi

    local latest_tag latest_ver
    latest_tag="$(github_latest_tag "$repo")" || { fail "$name: API GitHub KO"; return 1; }
    [[ -n "$latest_tag" ]] || { fail "$name: tag latest introuvable"; return 1; }
    latest_ver="${latest_tag#v}"

    if [[ -n "$installed_ver" ]] && [[ "$installed_ver" == "$latest_ver" ]] && [[ $force_upgrade -eq 0 ]]; then
        ok "$name: $installed_ver (à jour)"
        return 0
    fi

    if [[ -z "$installed_ver" ]]; then
        add "$name: $latest_ver"
    else
        upg "$name: $installed_ver → $latest_ver"
    fi

    local url="${url_tpl//\{TAG\}/$latest_tag}"
    url="${url//\{VER\}/$latest_ver}"

    if [[ $dry_run -eq 1 ]]; then
        printf '  [DRY-RUN] curl %s → %s/%s\n' "$url" "$LOCAL_BIN" "$name"
        return 0
    fi

    local tmpd="$TMP_ROOT/$name"
    mkdir -p "$tmpd"
    if ! curl -fsSL "$url" -o "$tmpd/dl" 2>/dev/null; then
        fail "$name: téléchargement échoué ($url)"
        return 1
    fi

    local ftype
    ftype="$(file -b "$tmpd/dl")"
    if [[ "$ftype" == *"gzip compressed"* ]]; then
        tar -xzf "$tmpd/dl" -C "$tmpd"
    elif [[ "$ftype" == *"Zip archive"* ]]; then
        unzip -qo "$tmpd/dl" -d "$tmpd"
    elif [[ "$ftype" == *"ELF"* ]] || [[ "$ftype" == *"executable"* ]]; then
        install -m 0755 "$tmpd/dl" "$LOCAL_BIN/$name"
        ok "$name: installé ($latest_ver)"
        return 0
    else
        fail "$name: type d'archive inconnu: $ftype"
        return 1
    fi

    local src
    src="$(find "$tmpd" -type f -name "$inner" | head -1)"
    [[ -n "$src" ]] || { fail "$name: binaire '$inner' introuvable dans l'archive"; return 1; }
    install -m 0755 "$src" "$LOCAL_BIN/$name"
    ok "$name: installé ($latest_ver)"
}

# -------- Group installers --------

install_core() {
    printf '\n\e[1m=== Core ===\e[0m\n'
    apt_ensure jq
    apt_ensure shellcheck
    apt_ensure yamllint
    apt_ensure git-flow
    apt_ensure curl
    apt_ensure unzip
    apt_ensure file

    # pipx : paquet varie selon version
    if ! command -v pipx >/dev/null; then
        apt_ensure_any pipx python3-pipx || true
    else
        ok "apt: pipx (déjà présent)"
    fi

    # Ensure ~/.local/bin via pipx
    if command -v pipx >/dev/null && [[ $dry_run -eq 0 ]]; then
        pipx ensurepath --quiet 2>/dev/null || true
    fi

    # shfmt : GitHub binary (pas fiable via apt sur toutes versions)
    github_install shfmt mvdan/sh \
        "https://github.com/mvdan/sh/releases/download/{TAG}/shfmt_{TAG}_linux_amd64" \
        "shfmt"

    pipx_ensure pre-commit
}

install_secrets() {
    printf '\n\e[1m=== Secrets scanning ===\e[0m\n'
    github_install gitleaks gitleaks/gitleaks \
        "https://github.com/gitleaks/gitleaks/releases/download/{TAG}/gitleaks_{VER}_linux_x64.tar.gz" \
        "gitleaks"
    pipx_ensure detect-secrets
}

install_python() {
    printf '\n\e[1m=== Python tooling ===\e[0m\n'
    pipx_ensure ruff
    pipx_ensure mypy
    pipx_ensure black
}

install_terraform() {
    printf '\n\e[1m=== Terraform + IaC security ===\e[0m\n'
    if command -v terraform >/dev/null; then
        if [[ $force_upgrade -eq 1 ]] && [[ $use_sudo -eq 1 ]]; then
            upg "terraform"
            run sudo apt-get install -y --only-upgrade terraform >/dev/null || true
        else
            ok "terraform (déjà installé)"
        fi
    else
        if [[ $use_sudo -eq 0 ]]; then
            sk "terraform (no-sudo)"
        else
            add "terraform (HashiCorp apt repo)"
            if [[ $dry_run -eq 0 ]]; then
                if [[ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]]; then
                    wget -qO- https://apt.releases.hashicorp.com/gpg \
                        | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                fi
                if [[ ! -f /etc/apt/sources.list.d/hashicorp.list ]]; then
                    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
                        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
                fi
                sudo apt-get update -qq
                sudo apt-get install -y terraform >/dev/null
            fi
        fi
    fi

    github_install tflint terraform-linters/tflint \
        "https://github.com/terraform-linters/tflint/releases/download/{TAG}/tflint_linux_amd64.zip" \
        "tflint"

    github_install tfsec aquasecurity/tfsec \
        "https://github.com/aquasecurity/tfsec/releases/download/{TAG}/tfsec-linux-amd64" \
        "tfsec-linux-amd64"

    pipx_ensure checkov
}

install_docker() {
    printf '\n\e[1m=== Docker ===\e[0m\n'
    github_install hadolint hadolint/hadolint \
        "https://github.com/hadolint/hadolint/releases/download/{TAG}/hadolint-Linux-x86_64" \
        "hadolint-Linux-x86_64"
}

install_ansible() {
    printf '\n\e[1m=== Ansible ===\e[0m\n'
    pipx_ensure ansible-lint
}

install_sql() {
    printf '\n\e[1m=== SQL ===\e[0m\n'
    pipx_ensure sqlfluff
}

# -------- Check mode --------

declare -A TOOL_GROUP=(
    [jq]=core [shellcheck]=core [shfmt]=core [yamllint]=core [git-flow]=core
    [pre-commit]=core [pipx]=core
    [gitleaks]=secrets [detect-secrets]=secrets
    [ruff]=python [mypy]=python [black]=python
    [terraform]=terraform [tflint]=terraform [tfsec]=terraform [checkov]=terraform
    [hadolint]=docker
    [ansible-lint]=ansible
    [sqlfluff]=sql
)

check_all() {
    printf '\e[1m=== Audit prérequis Claude Code ===\e[0m\n\n'
    local missing=0 total=0
    local tool ver group
    # Tri des clés (tools) pour affichage reproductible
    local sorted_tools
    sorted_tools=$(printf '%s\n' "${!TOOL_GROUP[@]}" | sort)
    while IFS= read -r tool; do
        total=$((total+1))
        group="${TOOL_GROUP[$tool]}"
        if command -v "$tool" >/dev/null 2>&1; then
            ver="$("$tool" --version 2>&1 | head -1 | head -c 80)"
            printf '  \e[32m✓\e[0m %-18s [%-9s] %s\n' "$tool" "$group" "$ver"
        else
            printf '  \e[31m✗\e[0m %-18s [%-9s] \e[31mMANQUANT\e[0m\n' "$tool" "$group"
            missing=$((missing+1))
        fi
    done <<< "$sorted_tools"
    printf '\n'
    if [[ $missing -eq 0 ]]; then
        info "Tous les prérequis sont installés ($total/$total)"
        return 0
    else
        warn "$missing outil(s) manquant(s) sur $total"
        info "Installation : $SCRIPT_NAME (tout) ou $SCRIPT_NAME --interactive"
        return 1
    fi
}

# -------- Interactive --------

interactive_select() {
    printf '\e[1mSélection des groupes à installer\e[0m\n\n'
    requested_groups=()
    for g in "${GROUPS_ORDER[@]}"; do
        printf '  \e[1m%s\e[0m : %s\n' "$g" "${GROUP_DESC[$g]}"
        read -r -p "    Installer ce groupe ? [Y/n] " reply </dev/tty || reply="y"
        if [[ ! "$reply" =~ ^[Nn]$ ]]; then
            requested_groups+=("$g")
            printf '    → ajouté\n'
        else
            printf '    → skip\n'
        fi
        echo
    done
    [[ ${#requested_groups[@]} -gt 0 ]] || die "Aucun groupe sélectionné"
    info "Groupes retenus : ${requested_groups[*]}"
}

# -------- Main --------

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Modes :
  --all              Installe tous les groupes (défaut)
  --interactive      Choix interactif par groupe
  --groups LISTE     Groupes spécifiques séparés par virgule
  --check            Audit seul, pas d'installation (exit code != 0 si manques)

Options :
  --dry-run          Affiche les actions sans les exécuter
  --upgrade          Force la mise à jour même si outil présent à jour
  --no-sudo          Skippe les paquets apt (user-space uniquement)
  -h, --help         Cette aide

Groupes :
EOF
    for g in "${GROUPS_ORDER[@]}"; do
        printf '  %-10s %s\n' "$g" "${GROUP_DESC[$g]}"
    done
    cat <<EOF

Les binaires GitHub vont dans : $LOCAL_BIN
Les outils Python sont installés isolés via pipx.
Les paquets système vont via apt (nécessite sudo).

Relance ce script manuellement quand tu veux mettre à jour.
EOF
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     usage; exit 0 ;;
            --all)         mode="all"; shift ;;
            --interactive) mode="interactive"; shift ;;
            --check)       mode="check"; shift ;;
            --groups)
                mode="specific"
                [[ -n "${2:-}" ]] || die "--groups requiert un argument"
                IFS=',' read -ra requested_groups <<< "$2"
                shift 2
                ;;
            --dry-run)     dry_run=1; shift ;;
            --upgrade)     force_upgrade=1; shift ;;
            --no-sudo)     use_sudo=0; shift ;;
            *)             die "Option inconnue : $1 (voir --help)" ;;
        esac
    done

    detect_os
    check_local_bin

    if [[ "$mode" == "check" ]]; then
        check_all
        exit $?
    fi

    if [[ "$mode" == "interactive" ]]; then
        interactive_select
    elif [[ "$mode" == "all" ]]; then
        requested_groups=("${GROUPS_ORDER[@]}")
    fi

    [[ ${#requested_groups[@]} -gt 0 ]] || die "Aucun groupe à installer"

    # 'core' est un prérequis transverse (pour pipx) → le forcer en premier
    if [[ " ${requested_groups[*]} " != *" core "* ]]; then
        info "Ajout implicite du groupe 'core' (requis pour pipx)"
        requested_groups=(core "${requested_groups[@]}")
    else
        # core en tête
        local new=(core)
        for g in "${requested_groups[@]}"; do
            [[ "$g" != "core" ]] && new+=("$g")
        done
        requested_groups=("${new[@]}")
    fi

    for g in "${requested_groups[@]}"; do
        case "$g" in
            core)      install_core ;;
            secrets)   install_secrets ;;
            python)    install_python ;;
            terraform) install_terraform ;;
            docker)    install_docker ;;
            ansible)   install_ansible ;;
            sql)       install_sql ;;
            *)         warn "Groupe inconnu ignoré : $g" ;;
        esac
    done

    printf '\n\e[1m=== Terminé ===\e[0m\n'
    info "Audit : $SCRIPT_NAME --check"
    info "Upgrade forcé : $SCRIPT_NAME --upgrade"
}

main "$@"
