#!/usr/bin/env bash
# danger-guard.sh — Bloque les commandes destructrices sans confirmation explicite.
# PreToolUse sur Bash.

set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

block() {
    echo "DANGER GUARD: $1" >&2
    echo "" >&2
    echo "Cette commande est potentiellement destructrice. Elle nécessite une validation explicite de l'utilisateur sur CETTE opération précise." >&2
    exit 2
}

# rm -rf dangereux
if echo "$command" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|-rf|-fr|--recursive\s+--force)'; then
    # Autoriser les suppressions dans /tmp et node_modules/.cache
    if ! echo "$command" | grep -qE '(/tmp/|node_modules|\.cache|dist/|build/)'; then
        block "rm -rf détecté hors des chemins safe (/tmp, node_modules, .cache, dist, build)."
    fi
fi

# git reset --hard
if echo "$command" | grep -qE 'git\s+reset\s+.*--hard'; then
    block "'git reset --hard' détecté. Demande confirmation à l'utilisateur."
fi

# Suppression de branche
if echo "$command" | grep -qE 'git\s+branch\s+-D\b'; then
    block "'git branch -D' (suppression forcée) détecté. Demande confirmation."
fi

# terraform destroy / apply
if echo "$command" | grep -qE 'terraform\s+destroy\b'; then
    block "'terraform destroy' détecté. OBLIGATOIREMENT demander confirmation à l'utilisateur."
fi

if echo "$command" | grep -qE 'terraform\s+apply\b' && ! echo "$command" | grep -qE '\-help|\-\-help'; then
    block "'terraform apply' détecté. Demande confirmation explicite à l'utilisateur avant d'appliquer des changements d'infra."
fi

# kubectl delete sans confirmation
if echo "$command" | grep -qE 'kubectl\s+delete\b' && ! echo "$command" | grep -qE '--dry-run'; then
    block "'kubectl delete' détecté sans --dry-run. Demande confirmation."
fi

# DROP TABLE / DATABASE (détection simpliste mais utile)
if echo "$command" | grep -qiE '\b(drop\s+(table|database|schema)|truncate\s+table)\b'; then
    block "Opération SQL destructrice détectée (DROP/TRUNCATE). Demande confirmation."
fi

# --no-verify (bypass hooks)
if echo "$command" | grep -qE '(git\s+commit|git\s+push).*--no-verify'; then
    block "'--no-verify' détecté. Les hooks existent pour une raison — demande à l'utilisateur si ce contournement est autorisé."
fi

exit 0
