#!/usr/bin/env bash
# context-injector.sh — Injecte un rappel du workflow méta + état git à chaque prompt utilisateur.
# UserPromptSubmit hook. Sort sur stdout = contenu ajouté au contexte de Claude.

set -euo pipefail

# État git si on est dans un repo
git_context=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || echo "?")
    dirty=""
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        dirty=" (modifié)"
    fi
    ahead_behind=""
    if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
        counts=$(git rev-list --left-right --count "@{u}"...HEAD 2>/dev/null || echo "0 0")
        behind=$(echo "$counts" | awk '{print $1}')
        ahead=$(echo "$counts" | awk '{print $2}')
        if [ "$ahead" != "0" ] || [ "$behind" != "0" ]; then
            ahead_behind=" | ahead:$ahead behind:$behind"
        fi
    fi
    git_context="Branche: $branch$dirty$ahead_behind"
fi

cat <<EOF
<claude-guidance>
RAPPEL WORKFLOW (cf. ~/.claude/CLAUDE.md) :
- Toute demande non triviale = Analyse → Explication → Plan → Attente du Go (pas d'action avant validation)
- Jamais de commit/push/apply/destroy/delete sans Go explicite sur CETTE opération
- GitFlow strict : pas de commit sur main/develop, feature/* depuis develop, hotfix/* depuis main
- Sauvegarde auto en mémoire les feedback/décisions importantes (sans demander)
${git_context:+- $git_context}
</claude-guidance>
EOF
