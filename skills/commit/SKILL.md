---
name: commit
description: Aide à formuler un message de commit soigné et cohérent. À invoquer quand on veut un message bien rédigé (format libre ou Conventional Commits au choix). Ne commit PAS automatiquement — prépare le message, l'utilisateur valide.
---

# Skill : Commit Helper

Prépare un message de commit de qualité. **Ne commit pas automatiquement** — propose, attend validation, exécute.

## Procédure

1. **Inspecter les changements** :
   ```bash
   git status
   git diff --cached       # si déjà staged
   git diff                # sinon
   ```

2. **Analyser** :
   - Type de changement : feat / fix / refactor / docs / test / chore / ci / perf / style
   - Scope : module/zone concernée
   - Motivation : **pourquoi** ce changement (pas le quoi, visible dans le diff)
   - Breaking changes éventuels
   - Tickets / issues référencés

3. **Proposer deux formats** (l'utilisateur choisit) :

### Format libre (défaut selon préférences user)
```
<résumé d'action, impératif, < 72 caractères>

<paragraphe optionnel : contexte / pourquoi — pas le quoi>

<référence ticket optionnelle>
```

Exemple :
```
Ajout du module MKS pour OVHcloud

Permet de provisionner un cluster Kubernetes managé multi-AZ sur
OVHcloud avec ses outputs standards (kubeconfig, endpoint, version).

Pré-requis pour l'env sandbox-par.
```

### Conventional Commits (si demandé)
```
<type>(<scope>): <résumé impératif>

<body optionnel>

<footer optionnel : BREAKING CHANGE, Refs>
```

Types : `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

Exemple :
```
feat(mks): add OVHcloud managed Kubernetes module

Provides multi-AZ cluster provisioning with standard outputs
(kubeconfig, endpoint, version).

Refs: #42
```

4. **Règles de contenu** (appliquées au format choisi) :
   - **Impératif** : "Ajoute" pas "Ajouté", "Add" pas "Added"
   - **Sujet < 72 caractères**
   - **Pas de point final** sur le sujet
   - **Ligne vide** entre sujet et body
   - **Body wrapped à ~80 caractères**
   - **Pourquoi > quoi** : le diff montre le quoi
   - **Un commit = une unité logique** : si 2 choses différentes, proposer 2 commits

5. **Si changements non staged** : demander ce qui doit être dans le commit
   - Si tout → `git add -A` (ou spécifique)
   - Si partiel → `git add <fichiers>` explicites ou `git add -p` interactif
   - **Ne jamais** ajouter automatique­ment ce qui ressemble à des secrets (`.env`, `*.key`, etc.)

6. **Afficher le message final** et attendre Go

7. **Commit** après Go avec HEREDOC :
   ```bash
   git commit -m "$(cat <<'EOF'
   <message>
   EOF
   )"
   ```

## Règles sécurité

- **Vérifier** avant commit : aucun secret dans le diff
- **Bloquer** si `.env` ou fichier suspect présent dans les staged — demander confirmation explicite
- **Signaler** si `--no-verify` est demandé (bypass hooks) — ne pas passer à moins d'un Go justifié
- **Jamais** commit sur `main` ou `develop` (le hook global bloque, mais rappel)

## Anti-patterns

- `"fix"` seul
- `"wip"` / `"update"` / `"changes"` sans contexte
- Messages qui décrivent le diff ligne par ligne
- Mix de plusieurs fixes dans un seul commit
- Commits avec 500+ fichiers modifiés sans justification

## Cas particuliers

- **Pur format/style** (pre-commit auto-fix) : `style: apply prettier` ou `chore: format`
- **Rollback** : `revert: <sujet du commit annulé>` (et noter le SHA)
- **Breaking change** : bien le signaler dans le footer (`BREAKING CHANGE: …`) même en format libre
