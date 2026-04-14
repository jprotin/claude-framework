---
name: bash
description: Expert Bash / shell scripting. À invoquer pour écrire scripts robustes, parser des arguments, manipuler fichiers/processus, debug. Déclencheurs : "bash", "sh", "shell", "script", "shellcheck".
---

# Skill : Bash Scripting

Tu es expert shell. Tu écris des scripts robustes, pas des one-liners fragiles.

## Template de base — OBLIGATOIRE

```bash
#!/usr/bin/env bash
#
# <nom>.sh — <description concise>
#
# Usage: <nom>.sh [options] <args>
#
set -euo pipefail
IFS=$'\n\t'

# Variables globales (UPPERCASE si readonly, sinon lowercase)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SCRIPT_NAME="${0##*/}"

# Logging
log()   { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*" >&2; }
info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*"; }
die()   { error "$*"; exit 1; }

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options] <arg>

Options:
  -h, --help         Affiche cette aide
  -v, --verbose      Mode verbeux
  -e, --env ENV      Environnement (dev|staging|prod)

Exemples:
  ${SCRIPT_NAME} --env prod deploy
EOF
}

main() {
    local env="dev"
    local verbose=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    usage; exit 0 ;;
            -v|--verbose) verbose=1; shift ;;
            -e|--env)     env="$2"; shift 2 ;;
            --)           shift; break ;;
            -*)           die "Option inconnue: $1 (utiliser -h)" ;;
            *)            break ;;
        esac
    done

    [[ $# -ge 1 ]] || { usage; exit 2; }

    info "env=$env verbose=$verbose args=$*"
    # … logique …
}

main "$@"
```

## Règles d'or

### Strict mode (dès la ligne 1)
```bash
set -euo pipefail
IFS=$'\n\t'
```
- `-e` : exit si commande fail
- `-u` : exit si variable non définie (attraper les typos)
- `-o pipefail` : exit si n'importe quelle commande d'un pipe fail
- `IFS` sûr : évite splitting sur espaces

### Quoting systématique
```bash
# BON
rm -rf "${dir}/cache"
for f in "$@"; do echo "$f"; done

# DANGEREUX
rm -rf $dir/cache      # si $dir vide → rm -rf /cache
for f in $*; do …      # split sur espaces
```

### `[[ ]]` (bash) pour tests
```bash
if [[ -f "$file" && "$env" == "prod" ]]; then …
if [[ "$str" =~ ^[0-9]+$ ]]; then …       # regex
```
`[ ]` POSIX seulement si shebang `#!/bin/sh`.

### Variables locales
```bash
my_func() {
    local input="$1"
    local result
    result=$(process "$input")
    echo "$result"
}
```

### Erreurs explicites
```bash
command || die "command failed"
[[ -f "$file" ]] || die "missing: $file"
```

### Pas de `cd` bancal
```bash
# Toujours dans un sous-shell ou avec trap
(cd /tmp/work && do_stuff)

# ou
pushd /tmp/work >/dev/null
trap 'popd >/dev/null' EXIT
do_stuff
```

### Trap pour cleanup
```bash
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT INT TERM

# … utiliser $tmpdir …
```

### Vérifier les dépendances
```bash
require() {
    command -v "$1" >/dev/null 2>&1 || die "Commande requise absente: $1"
}
require jq
require curl
```

## Parsing d'arguments avancé

Pour options longues + valeurs :
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --env=*)      env="${1#--env=}"; shift ;;
        --env)        env="$2"; shift 2 ;;
        --dry-run)    dry_run=1; shift ;;
        --)           shift; break ;;
        -*)           die "Option inconnue: $1" ;;
        *)            args+=("$1"); shift ;;
    esac
done
```

Pour très gros scripts, envisager `getopt` (GNU) ou réécrire en Python.

## Patterns utiles

### Lecture ligne par ligne
```bash
while IFS= read -r line; do
    echo "Line: $line"
done < "$file"
```

### Remplacement de string
```bash
path="/home/user/file.txt"
echo "${path##*/}"    # file.txt  (basename)
echo "${path%/*}"     # /home/user (dirname)
echo "${path%.*}"     # /home/user/file (sans ext)
echo "${path##*.}"    # txt (ext)
echo "${path/user/bob}"   # /home/bob/file.txt (1er replace)
echo "${path//o/0}"       # tous les 'o' → '0'
```

### Arrays
```bash
declare -a files=()
files+=("a.txt")
files+=("b.txt")

for f in "${files[@]}"; do
    echo "$f"
done

echo "${#files[@]}"     # taille
```

### Dictionnaires (bash 4+)
```bash
declare -A config
config[env]="prod"
config[region]="eu-west-1"

for key in "${!config[@]}"; do
    echo "$key = ${config[$key]}"
done
```

### Confirmer avant action destructrice
```bash
confirm() {
    local prompt="${1:-Continuer ?}"
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

confirm "Détruire $env ?" || die "Annulé"
```

## Debugging

```bash
set -x          # trace
set +x          # off

# Ou en ligne
bash -x script.sh

# Avec PS4 plus utile
export PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]:-main}: '
```

## Tests de scripts

- **`bats`** (Bash Automated Testing System) pour unitaire
- Tester les fonctions séparément (sourcer le script depuis les tests)
- Pas de fonctions > 20 lignes → refactorer

## Red flags

- Pas de `set -euo pipefail`
- Variables non quotées
- `$*` au lieu de `"$@"`
- `cd X && …` sans trap/push/pop
- Pas de validation des args
- `eval` avec du input
- Comparaison string avec `=` sans `[[`
- Pipe vers `while` sans `IFS=` + `-r`
- `rm -rf $var` sans vérif de non-vide
- Shebang `#!/bin/bash` quand `#!/usr/bin/env bash` est plus portable
- Pas passé par `shellcheck`

## Outils

- **`shellcheck`** : linter (doit être 0 warning)
- **`shfmt`** : formatter (`-i 2 -ci`)
- **`bats`** : tests
- **`bash -n script.sh`** : vérif syntaxe sans exécuter

## Quand quitter bash pour Python ?

Dès que le script dépasse **~150 lignes utiles** OU nécessite :
- Manipulation JSON/YAML sérieuse (`jq` acceptable, mais pas pour logique complexe)
- Tests unitaires
- Concurrence
- Gestion d'erreur riche
- Logique métier

## Learnings

<!-- Enrichi via /skill-enrich bash -->
