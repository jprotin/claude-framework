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

# ---- Orchestrateurs / registres : évalués commande simple par commande simple ----
# La ligne est découpée sur && || ; | & pour que l'exemption --dry-run d'une commande
# ne couvre pas la suivante ('kubectl apply --dry-run=client && kubectl delete ns x').
# Les regex 'kubectl...' matchent aussi les formes wrappées ('rtk kubectl', 'sudo kubectl').
# NB: motifs '[-][-]...' et non '--...' — sinon grep prend le motif pour une option.

# Flags globaux tolérés entre l'outil et le verbe ('kubectl -n prod apply', '--context=x').
# Flags à valeur séparée connus d'abord, puis tout flag (avec éventuel '=valeur').
readonly GLOBAL_FLAGS='(\s+(-n|--namespace|--context|--kube-context|--kubeconfig|--cluster|--user|-s|--server|--token|--as|--grpc-web-root-path)(=|\s+)\S+|\s+-{1,2}[A-Za-z][A-Za-z0-9-]*(=\S+)?)*'

# Seuls --dry-run, --dry-run=client et --dry-run=server n'appliquent rien (=none applique)
readonly SAFE_DRY_RUN='[-][-]dry-run(=(client|server))?(\s|$)'

while IFS= read -r segment; do
    [[ -z "${segment// /}" ]] && continue

    # kubectl mutations sans --dry-run
    if echo "$segment" | grep -qE "kubectl${GLOBAL_FLAGS}\s+(delete|apply|patch|edit|replace|scale|create|set|annotate|label|cordon|drain|uncordon|taint)\b" \
        && ! echo "$segment" | grep -qE "$SAFE_DRY_RUN"; then
        block "'kubectl <mutation>' détecté sans --dry-run=client|server (delete/apply/patch/edit/replace/scale/create/set/annotate/label/cordon/drain/taint). Demande confirmation."
    fi

    # kubectl rollout mutant (restart/undo/pause/resume) — 'rollout status|history' restent libres
    if echo "$segment" | grep -qE "kubectl${GLOBAL_FLAGS}\s+rollout\s+(restart|undo|pause|resume)\b"; then
        block "'kubectl rollout <mutation>' détecté. Demande confirmation."
    fi

    # helm mutations
    if echo "$segment" | grep -qE "helm${GLOBAL_FLAGS}\s+(install|upgrade|uninstall|delete|rollback)\b"; then
        block "'helm <mutation>' détecté. Demande confirmation."
    fi

    # argocd mutations
    if echo "$segment" | grep -qE "argocd${GLOBAL_FLAGS}\s+app\s+(sync|delete|set|create|rollback|patch)\b"; then
        block "'argocd app <mutation>' détecté. Demande confirmation."
    fi

    # push d'image conteneur : 'push', 'image push', 'build[x] ... --push'
    if echo "$segment" | grep -qE "(docker|podman|nerdctl)${GLOBAL_FLAGS}\s+(image\s+)?push\b" \
        || echo "$segment" | grep -qE '(docker|podman|nerdctl)\s.*\bbuild\b.*[-][-]push\b'; then
        block "push d'image conteneur détecté (docker/podman/nerdctl push, image push, build --push). Demande confirmation."
    fi

    # genai.sh chemins mutants (deploy/destroy déclenchent terraform apply/destroy en sous-process,
    # non visibles par ce hook une fois lancés → bloquer l'entrée)
    if echo "$segment" | grep -qE 'genai\.sh\s+infra\s+(deploy|destroy)\b'; then
        block "'genai.sh infra deploy|destroy' détecté. Demande confirmation explicite."
    fi
done < <(printf '%s\n' "$command" | sed -E 's/&&|\|\||[;&|]/\n/g')
# ------------------------------------------------------------------------------

# DROP TABLE / DATABASE (détection simpliste mais utile)
if echo "$command" | grep -qiE '\b(drop\s+(table|database|schema)|truncate\s+table)\b'; then
    block "Opération SQL destructrice détectée (DROP/TRUNCATE). Demande confirmation."
fi

# --no-verify (bypass hooks)
if echo "$command" | grep -qE '(git\s+commit|git\s+push).*--no-verify'; then
    block "'--no-verify' détecté. Les hooks existent pour une raison — demande à l'utilisateur si ce contournement est autorisé."
fi

exit 0
