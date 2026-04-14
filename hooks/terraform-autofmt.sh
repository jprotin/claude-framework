#!/usr/bin/env bash
# terraform-autofmt.sh — Formate automatiquement les fichiers Terraform après édition.
# PostToolUse sur Edit/Write matchant *.tf / *.tfvars.

set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

case "$tool_name" in
    Edit|Write|MultiEdit) ;;
    *) exit 0 ;;
esac

# Ne traiter que les fichiers terraform
case "$file_path" in
    *.tf|*.tfvars|*.hcl) ;;
    *) exit 0 ;;
esac

# Vérifier que terraform est dispo
if ! command -v terraform >/dev/null 2>&1; then
    exit 0
fi

# Formater le fichier (silencieux si OK)
terraform fmt "$file_path" >/dev/null 2>&1 || true

exit 0
