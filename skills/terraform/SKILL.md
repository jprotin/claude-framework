---
name: terraform
description: Expert Terraform / OpenTofu. À invoquer pour écrire ou refactorer des modules, gérer le state, concevoir des workspaces, résoudre un drift, sécuriser une config IaC. Déclencheurs : "terraform", "tofu", "hcl", "module tf", "state", "tfstate".
---

# Skill : Terraform / OpenTofu

Tu es expert Terraform/OpenTofu. Tu écris du HCL idiomatique, sécurisé et maintenable.

## Structure projet standard

```
project/
├── modules/
│   └── <nom>/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── envs/
│   ├── dev/
│   │   ├── main.tf           # appelle les modules
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── versions.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars.example
│   └── prod/
└── examples/
```

## Règles d'or

### Versions
- Toujours pinner : `required_version = "~> 1.9"`
- Providers : `~> 2.5` (pas `>= 0`)
- Lockfile `.terraform.lock.hcl` **committé**

### Naming
- `snake_case` partout
- Ressources : `resource "aws_s3_bucket" "logs"` (nom du rôle, pas du type)
- Variables : nom descriptif, pas abrégé
- Modules : verbe + objet (`create-vpc`, `manage-dns`)

### Variables
```hcl
variable "environment" {
  type        = string
  description = "Nom de l'environnement (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment doit être dev, staging ou prod."
  }
}

variable "api_token" {
  type        = string
  description = "Token API"
  sensitive   = true
}
```

### Outputs
- Toujours avec `description`
- `sensitive = true` si contient des secrets
- Ne jamais exposer en output ce qui n'est pas nécessaire à un consommateur

### Modules
- **Une responsabilité** par module
- **Entrées minimales** : ce qui change entre usages, pas plus
- **Sorties utiles** : ce dont les consommateurs ont besoin
- **README.md** : exemple d'usage, inputs, outputs
- **Versionnés** via tags git (`v1.2.0`) si consommés ailleurs

## Gestion du state

### Backend distant obligatoire
```hcl
terraform {
  backend "s3" {
    bucket         = "my-tf-states"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
```

OVHcloud : Swift backend ou Terraform Cloud.

### Règles state
- **Jamais** commit le state (dans `.gitignore`)
- **Lock** systématique (DynamoDB, consul…)
- **Chiffré** au repos
- **Versionné** (bucket versioning activé)
- `terraform state` **lecture** autorisée, `state rm`/`mv` avec backup
- Séparer le state par env (pas un seul state pour dev+staging+prod)

### Import de ressources existantes
```bash
terraform import module.vpc.aws_vpc.main vpc-12345
# Puis écrire le HCL correspondant et faire terraform plan → aucun diff attendu
```

## Workspaces vs dossiers env

| Approche | Quand |
|---|---|
| **Dossiers par env** (`envs/dev/`, `envs/prod/`) | ✅ Configs vraiment différentes, cloisonnement strict |
| **Workspaces** | Petites variations, même code, différents tfvars |

Recommandé : dossiers par env pour les projets sérieux.

## Sécurité

- `sensitive = true` sur variables secrets → masqués dans les logs
- Jamais de secrets dans `.tfvars` commité → `*.tfvars.example` sans valeurs
- Variables d'env `TF_VAR_xxx` pour CI/CD
- `tfsec` + `checkov` en pre-commit
- Rôles IAM / policies : minimum nécessaire

## Patterns utiles

### `for_each` sur une map
```hcl
resource "aws_iam_user" "users" {
  for_each = toset(["alice", "bob", "carol"])
  name     = each.key
}
```

### Conditional
```hcl
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0
  # ...
}
```

### Data sources pour référencer existant
```hcl
data "aws_vpc" "selected" {
  tags = { Environment = var.environment }
}
```

### Locals pour lisibilité
```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

## Drift et maintenance

- **Scheduled `terraform plan`** en CI (nightly) → alerte si drift
- **`terraform state rm` + import** pour reprendre en main des ressources modifiées hors TF
- **Refactoring** : `moved {}` block (TF 1.1+) pour renommer sans détruire

```hcl
moved {
  from = aws_s3_bucket.old_name
  to   = aws_s3_bucket.new_name
}
```

## Red flags

- State local non versionné
- `terraform apply` depuis laptop dev sans review
- Secrets dans `terraform.tfvars` commité
- Module monstrueux (500+ lignes) au lieu de modules composés
- Pas de `versions.tf` ou versions en `>= 0`
- `count` abusé là où `for_each` est plus clair
- Provider version floue → breaking change à la prochaine init
- Pas de backend distant en équipe (conflits de state)
- `terraform destroy` dans un script automatisé sans garde-fou

## Commandes cheatsheet

```bash
terraform init -upgrade        # met à jour providers
terraform fmt -recursive       # format
terraform validate             # syntaxe + cohérence
terraform plan -out tfplan     # plan dans fichier
terraform apply tfplan         # apply du plan sauvé
terraform state list           # voir les ressources
terraform state show <addr>    # détail d'une ressource
terraform state rm <addr>      # retirer du state (sans détruire)
terraform import <addr> <id>   # importer ressource existante
terraform output               # voir outputs
terraform console              # REPL pour tester expressions
terraform graph | dot -Tpng > graph.png  # graphique
```

## OpenTofu

- Fork libre de Terraform (après la license change Hashicorp 2023)
- Compatible avec Terraform < 1.6
- Passer par `tofu` au lieu de `terraform` si préféré (mêmes commandes)

## Learnings

<!-- Enrichi via /skill-enrich terraform -->

### 2026-04-15 — Contraintes de version providers : modules ↔ envs doivent s'intersecter
Les `required_providers` d'un **module** et d'un **env** qui l'appelle sont combinés par intersection de contraintes. Si elles ne s'intersectent pas (ex: module `~> 2.0` + env `~> 0.46`), `terraform init` échoue avec "Inconsistent dependency lock file".

**Quand :** ajout ou bump d'un provider dans un module existant.
**Pourquoi :** incident 2026-04-15 sur projet OVH — bump mks/network/compute à une majeure non alignée avec les envs.
**Règle :** aligner le module sur la contrainte des envs (la plus large réaliste), ne pas imposer de version majeure depuis le module. Si upgrade nécessaire, bumper env + module **en même temps**.

### 2026-04-15 — OVH provider : `service_name` = ID tenant 32 hex, PAS le nom friendly
Pour les ressources `ovh_cloud_project_*`, la variable `service_name` attend l'**ID tenant Public Cloud** (format hex 32 caractères, ex: `a1b2c3d4e5f6789012345678abcdef01`), PAS le nom affiché dans l'UI OVH.

**Erreur typique :** `OVHcloud API error (status code 404): Client::NotFound: "This service does not exist"`.

**Où trouver l'ID :** URL du Manager OVH → Public Cloud → projet → l'ID dans le path `/projects/XXXX/home`, ou via `ovhai project list`.

### 2026-04-15 — Gitignore : couvrir `openrc*.sh` et `kubeconfig*.yaml`
Les fichiers `openrc.sh` et `kubeconfig.yaml` peuvent exister en **plusieurs variantes** (ex: `openrc_PAR.sh`, `openrc_SBG.sh`, `kubeconfig-prod.yaml`). Un `.gitignore` qui n'exclut que `openrc.sh` laisse fuiter les variantes.

**Règle :** toujours utiliser des patterns glob (`openrc*.sh`, `kubeconfig*.yaml`, `kubeconfig*.yml`) pour les fichiers sensibles multi-variantes.

**Quand :** tout projet qui utilise plusieurs régions / environnements / clusters.
**Pourquoi :** fuite évitée : sur le projet Sandbox OVH (2026-04-15), `openrc_PAR.sh` et `openrc_SBG.sh` étaient NOT ignored alors que `openrc.sh` l'était.
