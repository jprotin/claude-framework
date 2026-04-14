#!/usr/bin/env bash
# gitflow-guard.sh — Bloque les opérations git qui violent GitFlow.
# Appelé par Claude Code en PreToolUse sur Bash.
# Lit le JSON d'entrée sur stdin, sort en code 2 (+ message stderr) pour bloquer.

set -euo pipefail

# Lecture du JSON d'entrée
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# On ne traite que Bash
if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

# On ignore si on n'est pas dans un repo git
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

current_branch=$(git branch --show-current 2>/dev/null || echo "")

# GitFlow considéré actif si la branche 'develop' existe dans le repo.
# Sinon : workflow simple (main-only ou GitHub Flow) → les règles GitFlow ne s'appliquent pas.
gitflow_active=0
if git show-ref --verify --quiet refs/heads/develop 2>/dev/null; then
    gitflow_active=1
fi

block() {
    echo "GITFLOW GUARD: $1" >&2
    echo "" >&2
    echo "Si tu souhaites vraiment contourner cette protection, utilise une commande différente ou demande à l'utilisateur de le faire manuellement." >&2
    exit 2
}

# 1. Bloquer commit direct sur main/develop (uniquement si GitFlow actif)
if [[ $gitflow_active -eq 1 ]] && echo "$command" | grep -qE '(^|;|&&|\|\|)\s*git\s+commit\b'; then
    if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ] || [ "$current_branch" = "develop" ]; then
        block "Commit direct sur '$current_branch' interdit par GitFlow. Crée une branche feature/*, release/* ou hotfix/*."
    fi
fi

# 2. Bloquer création de feature/* hors de develop (uniquement si GitFlow actif)
if [[ $gitflow_active -eq 1 ]] && echo "$command" | grep -qE 'git\s+(checkout\s+-b|switch\s+-c|flow\s+feature\s+start)\s+feature/'; then
    if [ "$current_branch" != "develop" ]; then
        block "Une branche 'feature/*' doit être créée depuis 'develop' (tu es sur '$current_branch'). Fais 'git checkout develop && git pull' avant."
    fi
fi

# 3. Bloquer création de hotfix/* hors de main (uniquement si GitFlow actif)
if [[ $gitflow_active -eq 1 ]] && echo "$command" | grep -qE 'git\s+(checkout\s+-b|switch\s+-c|flow\s+hotfix\s+start)\s+hotfix/'; then
    if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
        block "Une branche 'hotfix/*' doit être créée depuis 'main' (tu es sur '$current_branch'). Fais 'git checkout main && git pull' avant."
    fi
fi

# 4. Bloquer création de release/* hors de develop (uniquement si GitFlow actif)
if [[ $gitflow_active -eq 1 ]] && echo "$command" | grep -qE 'git\s+(checkout\s+-b|switch\s+-c|flow\s+release\s+start)\s+release/'; then
    if [ "$current_branch" != "develop" ]; then
        block "Une branche 'release/*' doit être créée depuis 'develop' (tu es sur '$current_branch')."
    fi
fi

# 5. Bloquer push --force sur main/develop
if echo "$command" | grep -qE 'git\s+push\s+.*(--force\b|--force-with-lease\b|-f\b)'; then
    if echo "$command" | grep -qE '\b(main|master|develop)\b'; then
        block "push --force sur main/master/develop interdit. Si c'est volontaire, demande une confirmation explicite à l'utilisateur."
    fi
fi

# 6. Rappel double merge sur merge de release/* ou hotfix/*
if echo "$command" | grep -qE 'git\s+merge\s+.*\b(release|hotfix)/'; then
    echo "RAPPEL GITFLOW : après ce merge, vérifie que tu fais le DOUBLE MERGE (main + develop) et que tu poses un tag 'vX.Y.Z' sur main." >&2
    # On ne bloque pas, juste rappel
fi

exit 0
