#!/usr/bin/env bash
# run-danger-guard-tests.sh — Rejoue danger-guard.sh sur une table de cas.
# Format du fichier de cas (TSV) : <attendu>\t<commande>, attendu = B (bloquée) ou P (passe).
# Usage : hooks/tests/run-danger-guard-tests.sh [cases.tsv]

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TESTS_DIR
readonly HOOK="$TESTS_DIR/../danger-guard.sh"
readonly CASES="${1:-$TESTS_DIR/danger-guard.cases.tsv}"

total=0
failed=0
while IFS=$'\t' read -r expected cmd; do
    [[ -z "$cmd" ]] && continue
    total=$((total + 1))
    jq -n --arg c "$cmd" '{tool_name: "Bash", tool_input: {command: $c}}' \
        | bash "$HOOK" >/dev/null 2>&1
    if [[ $? -eq 2 ]]; then got=B; else got=P; fi
    if [[ "$got" != "$expected" ]]; then
        failed=$((failed + 1))
        printf 'KO  attendu=%s obtenu=%s  %s\n' "$expected" "$got" "$cmd"
    fi
done < "$CASES"

printf '%d/%d cas OK\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
