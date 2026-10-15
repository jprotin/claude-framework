# Politique RTK — compression sélective

**Version RTK** : 0.39.0 (`~/.local/bin/rtk`)
**Date d'établissement** : 2026-09-11
**Fichier de config** : `~/.config/rtk/config.toml`, section `[hooks] exclude_commands`

---

## Principe

RTK est branché en `PreToolUse:Bash` (`rtk hook claude` dans `settings.json`) et réécrit
automatiquement les commandes en leur équivalent compressé. En mode « tout compresser »,
cette réécriture peut coûter plus cher qu'elle ne rapporte : une sortie trop réduite oblige
à relancer la commande, ce qui ajoute un tour de conversation complet.

**Règle retenue** : RTK ne s'applique qu'aux commandes dont le gain a été **mesuré** et dont
la perte d'information est **bornée et signalée**. Tout le reste passe en sortie brute.

Le compteur `rtk gain` n'a servi à aucune décision : il mesure un contrefactuel (« ce que
ça aurait coûté sans RTK »), pas la facture réelle. Toutes les décisions ci-dessous
reposent sur une comparaison octet à octet des sorties réelles.

---

## Protocole de mesure

Pour chaque commande :

```bash
rtk run -c "<commande brute>"   > /tmp/x.raw 2>&1   # rtk run = exécution sans filtrage
rtk run -c "rtk <commande>"     > /tmp/x.rtk 2>&1
wc -c /tmp/x.raw /tmp/x.rtk                          # gain en octets
diff <(...) <(...)                                   # contrôle de fidélité
```

Contrôle de fidélité : les chemins, numéros de ligne, identifiants et messages d'erreur
doivent survivre. **Une information perdue silencieusement disqualifie la commande, quel
que soit le gain.**

---

## Décisions

### GARDER — RTK actif (4 familles)

| Commande | Brut | RTK | Gain | Fidélité |
|---|---|---|---|---|
| `kubectl logs` | 39 261 B / 400 l | 1 735 B / 25 l | **95,6 %** | Comptes exacts (49 erreurs / 41 warns / 310 infos), échantillon explicite avec `... +36 more` |
| `docker logs` | *(filtre `log` partagé)* | — | **95,6 %** | Idem — mesuré via `rtk log` sur le même corpus |
| `ls` | 1 061 B | 203 B | **80,9 %** | Perd permissions / propriétaire / dates ; garde noms + tailles |
| `git status` | 569 B | 133 B | **76,6 %** | **Intégrale** — branche, tracking, modifiés, non suivis. Ne perd que les conseils verbeux de git |

Point commun : sortie longue et répétitive, et perte **bornée + signalée** plutôt que
silencieuse.

### EXCLURE — sortie brute

#### Perte d'information avérée

| Commande | Gain | Motif du rejet |
|---|---|---|
| `git log` | 16,5 % | **Supprime tous les merge commits** — 4 sur 15 absents (`d602fe9`, `78d778c`, `6d0d828`, `7282465`). Disqualifiant sur un repo GitFlow où les merges portent l'information |
| `find` | **−359 %** | **Ignore `-path`, `-not`, `-exec`** et renvoie un résultat faux. 180 B → 826 B, soit 4,6× plus gros ET incorrect |
| `ps` | 95,8 % | Tronque 535 → 31 lignes en gardant les 30 premiers kernel threads et en supprimant tous les processus applicatifs. Inutilisable pour retrouver un processus |
| `docker images` | 72,6 % | Supprime les IDs d'image, tronque les noms de repo en tête (`.../<registry>/...`), masque 5 images sur 20 |
| `grep` / `rg` | 37 % | Tronque les lignes à 80 caractères avec `...` au milieu — le code trouvé doit être relu ailleurs |
| `terraform` / `tofu` | 0,3 % | Aucun gain, **et injecte une ligne fausse** : affiche `terraform plan: no changes detected` alors que le plan a échoué en erreur |
| `wc` | 29,9 % | Supprime les chemins en multi-fichiers ; gain absolu de 40 octets |

#### Gain nul ou négatif

| Commande | Brut | RTK | Gain |
|---|---|---|---|
| `git diff` | 2 839 B | 2 909 B | **−2,5 %** |
| `make` | 73 B | 82 B | **−12,3 %** |
| `kubectl describe` | 5 029 B | 5 028 B | 0,0 % |
| `docker ps` | 2 997 B | 2 997 B | 0,0 % |
| `cat` / `rtk read` | 15 384 B | 15 384 B | 0,0 % |
| `git show` | 314 B | 314 B | 0,0 % |
| `yamllint` | 755 B | 755 B | 0,0 % |
| `df`, `du`, `systemctl status`, `gcloud` | — | — | 0,0 % |
| `kubectl get` | 722 B | 721 B | 0,1 % |
| `pre-commit` | 234 B | 233 B | 0,4 % |
| `shellcheck` | 337 B | 335 B | 0,6 % |
| `tree` | 2 431 B | 2 405 B | 1,1 % |

#### Exclus par règle, non mesurés

Outils dont la sortie est dense en information actionnable (chemins + numéros de ligne +
messages d'erreur), où le risque de perdre une ligne dépasse le gain espéré :

`tsc`, `mypy`, `ruff`, `eslint`, `biome`, `prettier`, `golangci-lint`, `markdownlint`,
`hadolint`, `pytest`, `jest`, `vitest`, `playwright`, `cargo`, `go`, `rspec`, `rubocop`,
`mvn`, `dotnet`, `swift`, `npm`, `npx`, `pnpm`, `pip`, `uv`, `poetry`, `composer`,
`gh`, `glab`, `gt`, `helm`, `aws`, `ansible-playbook`, `sops`, `psql`, `curl`, `wget`.

**À mesurer avant réactivation** — le protocole ci-dessus s'applique tel quel. Les filtres
test-runners (`pytest`, `cargo test`) sont le cœur de métier revendiqué de RTK et
mériteront une mesure au premier projet concerné.

---

## Configuration appliquée

`~/.config/rtk/config.toml` :

```toml
[hooks]
exclude_commands = [
    # git : tout sauf 'git status'
    "^git (log|diff|show|add|commit|push|pull|branch|fetch|stash|worktree)",
    "^yadm",
    # forges
    "^gh", "^glab", "^gt",
    # fichiers / recherche
    "^cat", "^head", "^tail", "^grep", "^rg", "^find", "^tree", "^wc", "^rsync",
    # node / js / ts
    "^npm", "^npx", "^pnpm", "^tsc", "^eslint", "^biome", "^prettier",
    "^jest", "^vitest", "^playwright", "^prisma", "^next",
    # python
    "^pytest", "^mypy", "^ruff", "^pip", "^uv", "^poetry",
    # autres langages
    "^cargo", "^go", "^golangci-lint", "^dotnet", "^mvn", "^swift", "^mix",
    "^bundle", "^rake", "^rails", "^rspec", "^rubocop", "^composer",
    "^trunk", "^pio", "^quarto", "^liquibase", "^shopify",
    # infra : tout sauf 'kubectl logs' et 'docker logs'
    "^terraform", "^tofu",
    "^kubectl (get|describe|apply)",
    "^docker (ps|images|run|exec|build|compose)",
    "^helm", "^aws", "^gcloud", "^ansible-playbook", "^sops", "^iptables",
    "^fail2ban-client", "^systemctl", "^psql", "^brew",
    # lint / qualite
    "^shellcheck", "^yamllint", "^markdownlint", "^hadolint", "^pre-commit",
    # systeme / reseau
    "^df", "^du", "^ps", "^make", "^ping", "^wget", "^curl",
]
```

76 motifs. Sauvegarde de l'état antérieur : `~/.config/rtk/config.toml.bak.2026-09-11`.

### Syntaxe de `exclude_commands` (établie empiriquement)

La documentation ne décrit pas cette clé. Comportement observé sur 0.39.0 :

| Forme | Effet |
|---|---|
| `"git"` | Préfixe **littéral**. Exclut `git …` |
| `"kubectl get"` | Préfixe littéral multi-mots — fonctionne |
| `"^git (log\|diff)"` | Mode **regex**, activé par le `^` initial. Alternations supportées |
| `"git (log\|diff)"` | **Sans effet** — sans `^`, le motif reste littéral |
| `"^git\s+log"` | **Sans effet** — `\s` et `\b` ne sont pas honorés. Utiliser une espace littérale |
| `"."`, `".*"` | Ignorés (rejetés comme « trivial ») — un catch-all est impossible |

Un suffixe `($|\s)` est ajouté implicitement : `"gi"` ne matche pas `git status`.

Vérification d'un motif : `rtk hook check <commande>` (dry-run, n'exécute rien).
Sortie `No rewrite for: …` = commande exclue, sortie brute.

---

## Limites connues

1. **Portée globale.** `config.toml` est unique (`XDG_CONFIG_HOME/rtk/config.toml`) ; il
   n'existe ni config par projet ni variable `RTK_CONFIG`. Cette politique s'applique à
   tous les projets de la machine. Le `.rtk/filters.toml` projet ne permet
   que d'**ajouter** des filtres, pas d'en exclure.

2. **Liste noire, pas liste blanche.** `exclude_commands` ne sait qu'exclure, et les motifs
   catch-all sont rejetés. La liste blanche de fait est obtenue par énumération des 76
   préfixes à exclure : **tout nouvel outil ajouté au moteur RTK sera actif par défaut** et
   devra être mesuré puis ajouté ici.

3. **Bug 0.39.0 — `head -N` / `tail -N` échappent à l'exclusion.** `head -5 f`,
   `tail -20 f` et `tail -n 20 f` sont réécrits en `rtk read --max-lines/--tail-lines`
   malgré `"^head"` / `"^tail"`, quel que soit le motif employé. `head -n 5 f`, `cat -n f`
   et `tail -f` sont correctement exclus. Impact faible (la réécriture est sémantiquement
   équivalente). Contournement : `head -n 5` plutôt que `head -5`, ou `RTK_DISABLED=1`.

4. **Préfixes `git -C <dir>`.** Le moteur RTK réécrit `git -C /path log`, mais les motifs
   `^git (log|…)` ne le matchent pas. Peu fréquent en pratique.

5. **`env` n'est pas concerné.** `rtk env` existe comme sous-commande manuelle (70 % de
   gain mesuré : 110 → 48 variables, le bruit desktop retiré) mais le hook ne réécrit pas
   `env`. Rien à exclure. À invoquer à la main si utile — avec la réserve que `PATH` est
   tronqué à 338 caractères.

6. **Mode `awareness` : inexistant en 0.39.0.** Aucune clé de ce nom dans le binaire ni
   dans la configuration. Rien appliqué de ce côté (décision validée). Les réglages
   voisins, laissés à leur valeur par défaut, sont `[tracking].enabled`,
   `[telemetry].enabled` et `[display].emoji` / `.colors`.

---

## Exploitation au quotidien

```bash
# Forcer la sortie brute ponctuellement, sur une commande normalement compressée
RTK_DISABLED=1 <commande>

# Forcer la compression ponctuellement, sur une commande exclue
rtk <commande>          # ex. rtk git log --oneline -20

# Vérifier ce que le hook ferait, sans exécuter
rtk hook check <commande>

# Vérifier l'intégrité du hook et des filtres
rtk verify
```

## Révision

Cette politique se revalide en rejouant le protocole de mesure, notamment :

- à chaque montée de version de RTK (les filtres changent sans préavis) ;
- avant d'ajouter un outil à la liste « exclus par règle, non mesurés » ;
- si une commande « GARDER » provoque une relance pour information manquante — c'est le
  signal exact que le gain est illusoire.
