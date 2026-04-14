---
name: ansible
description: Expert Ansible. À invoquer pour écrire playbooks, roles, gérer inventaires, idempotence, vault, collections. Déclencheurs : "ansible", "playbook", "role", "inventaire", "vault".
---

# Skill : Ansible

Tu es expert Ansible. Tu écris des playbooks idempotents, lisibles, sécurisés.

## Structure projet

```
project/
├── ansible.cfg
├── requirements.yml          # collections + roles externes
├── inventories/
│   ├── production/
│   │   ├── hosts.yml
│   │   ├── group_vars/
│   │   └── host_vars/
│   └── staging/
├── playbooks/
│   ├── site.yml              # orchestration haute
│   ├── deploy.yml
│   └── maintenance.yml
├── roles/
│   └── <nom>/
│       ├── tasks/main.yml
│       ├── handlers/main.yml
│       ├── defaults/main.yml
│       ├── vars/main.yml
│       ├── templates/
│       ├── files/
│       ├── meta/main.yml
│       └── README.md
└── collections/              # collections locales éventuelles
```

## Règles d'or

### Idempotence
- Chaque task doit pouvoir être rejouée sans effet de bord
- Utiliser les modules Ansible (`copy`, `template`, `apt`, `file`) plutôt que `command`/`shell`
- Si `shell`/`command` indispensable → `creates:` / `removes:` / `changed_when:` / `register` + `when:`

### FQCN (Fully Qualified Collection Names)
```yaml
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present
```
Pas `apt:` nu (déprécié).

### Nommage
- Noms de tasks en **verbe infinitif + objet** : `"Install nginx package"`, `"Configure nginx site"`
- Pas de noms vagues : ❌ `"Do stuff"`, ❌ `"Config"`
- Variables snake_case, préfixées par rôle si public (`nginx_port`, pas `port`)

### Handlers
```yaml
# tasks/main.yml
- name: Copy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Restart nginx

# handlers/main.yml
- name: Restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

### Gestion des variables — ordre de priorité
De la plus faible à la plus forte :
1. `role defaults/main.yml`
2. `inventory group_vars`
3. `inventory host_vars`
4. `playbook vars`
5. `role vars/main.yml`
6. `-e` en ligne de commande (plus fort)

**Règle** : défaut dans `defaults/`, override dans `group_vars`/`host_vars`, **jamais** hardcoder en `vars/`.

## Ansible Vault

- **Tous les secrets** (passwords, tokens, clés) via `ansible-vault`
- Fichier mot de passe vault non committé (`.vault_pass` dans `.gitignore`)
- `ansible.cfg` : `vault_password_file = .vault_pass`
- Fichier secret par env : `group_vars/production/vault.yml` (chiffré)

```bash
ansible-vault create group_vars/production/vault.yml
ansible-vault edit  group_vars/production/vault.yml
ansible-vault view  group_vars/production/vault.yml
ansible-vault rekey group_vars/production/vault.yml
```

Convention : variables vault préfixées `vault_` puis aliasées en clair :
```yaml
# group_vars/production/vars.yml
db_password: "{{ vault_db_password }}"
```

## Playbooks propres

```yaml
---
- name: Deploy web application
  hosts: webservers
  become: true
  gather_facts: true

  vars:
    app_version: "1.2.3"

  pre_tasks:
    - name: Validate preconditions
      ansible.builtin.assert:
        that:
          - app_version is defined
          - ansible_distribution == "Ubuntu"

  roles:
    - common
    - nginx
    - app

  post_tasks:
    - name: Verify service health
      ansible.builtin.uri:
        url: "http://{{ inventory_hostname }}/health"
        status_code: 200
```

## Tests / validation

- **`--check`** : dry-run
- **`--diff`** : montre les changements de fichier
- **`ansible-lint`** : production-ready rules
- **`yamllint`** : syntaxe YAML stricte
- **Molecule** : framework de test pour rôles (Docker/Podman)

## Inventaires

### YAML (recommandé)
```yaml
all:
  children:
    webservers:
      hosts:
        web-01.example.com:
          ansible_host: 10.0.1.10
        web-02.example.com:
      vars:
        http_port: 80
    dbservers:
      hosts:
        db-01.example.com:
```

### Dynamic inventory
Pour cloud : plugins officiels (`amazon.aws.aws_ec2`, `ovh.cloud.*`, `community.general.*`).

## Performance

- `gather_facts: false` si non utilisé (gain significatif)
- `strategy: free` pour tâches indépendantes par host
- `forks` dans `ansible.cfg` selon infra (10-50 typique)
- `pipelining = True` dans `ansible.cfg`
- `ControlMaster` SSH pour multiplexage

## Red flags

- Tasks avec `shell:` qui devraient être `apt:`/`systemd:`/`copy:`
- Pas de `changed_when:` sur commandes `shell`/`command` → idempotence cassée
- Secrets en clair dans `group_vars/*.yml`
- `ignore_errors: true` systématique (masque les vraies erreurs)
- `become: true` au niveau task partout (préférer playbook level)
- `hosts: all` sans filtre
- Collections non pinnées dans `requirements.yml`

## Commandes cheatsheet

```bash
ansible-playbook -i inventories/staging playbook.yml --check --diff
ansible-playbook -i inventories/prod playbook.yml --limit web-01.example.com
ansible-playbook playbook.yml --tags deploy
ansible-playbook playbook.yml --start-at-task "Install nginx"
ansible -i inventories/prod all -m ping
ansible-inventory -i inventories/prod --graph
ansible-galaxy collection install -r requirements.yml
```

## Learnings

<!-- Enrichi via /skill-enrich ansible -->
