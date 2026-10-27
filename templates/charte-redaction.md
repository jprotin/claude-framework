# Charte de rédaction — écrire pour être lu

> **En bref** — Tout document produit par le framework (spec, plan, tasks, rapports, ADR,
> documentation) doit pouvoir être lu par quelqu'un qui ne connaît pas le projet. On commence
> par l'essentiel en mots simples, on garde le détail technique, mais replié. Cette charte
> s'applique aux nouveaux documents ; les anciens ne sont pas réécrits.

## Pour qui on écrit

Le lecteur type est intelligent mais extérieur au sujet : un chef de projet, un client, un
nouvel arrivant, ou vous-même dans six mois. Il doit comprendre en deux minutes **de quoi il
s'agit, pourquoi, ce que ça change et ce qu'on attend de lui**.

Le développeur qui a besoin du détail le trouve plus bas, dans les parties repliées.

## La structure de chaque document

1. **Un titre qui dit ce que c'est**, sans identifiant seul. « Connexion par SSO : la spec »
   plutôt que « Spec — auth-sso-saml ».
2. **« En bref »** juste sous le titre : 3 à 5 phrases, sans jargon. Qu'est-ce que c'est ?
   Pourquoi ? Qu'est-ce que ça change ? Qu'attend-on du lecteur (une décision, une validation,
   rien) ?
3. **Le corps**, dans l'ordre qui sert le lecteur : le pourquoi, puis le quoi, puis l'impact,
   puis ce qui reste à décider.
4. **Les détails techniques repliés** : chemins de fichiers, schémas de données, commandes,
   longues listes, justifications fines.
5. **Un glossaire** en fin de document dès que trois termes techniques ou plus sont utilisés.

Le format, compatible MkDocs, GitHub et Azure DevOps :

```markdown
# Connexion par SSO : la spec

> **En bref** — Les utilisateurs se connecteront avec leur compte d'entreprise au lieu d'un
> mot de passe propre à l'application. Cela supprime la gestion des mots de passe et
> centralise les départs. Il faut valider la liste des groupes autorisés (section 4).

## Pourquoi
...

<details markdown="1">
<summary>Détails techniques</summary>

...contenu technique, tableaux complets, chemins, commandes...

</details>

## Glossaire

- **SSO** (authentification unique) : se connecter une seule fois pour plusieurs applications.
```

Laisser une ligne vide après `<summary>` et avant `</details>`, sinon le Markdown à
l'intérieur ne s'affiche pas.

## Les règles d'écriture

**Phrases**
- Une idée par phrase, 25 mots au maximum.
- Voix active, sujet clair : « l'API refuse la requête » plutôt que « la requête est refusée ».
- Des verbes concrets : « supprimer », « bloquer », « afficher » plutôt que « adresser »,
  « impacter », « challenger ».

**Mots**
- Le mot courant d'abord. Un terme technique indispensable est expliqué à sa première
  apparition, puis repris dans le glossaire.
- Aucun sigle sans sa forme longue la première fois : « RGPD (règlement européen sur les
  données personnelles) ».
- **Jamais d'identifiant seul** dans la partie visible : « RF-3 (export PDF) », « TASK-12
  (page de connexion) », « le bloquant B2 (perte de données au rechargement) ».
- Les statuts en mots : « Terminé », « En cours », « Bloqué : en attente de l'accès Azure ».

**Mise en forme**
- Une liste dépasse rarement 7 éléments. Au-delà, regrouper (par lot, par thème).
- Un tableau visible a 5 colonnes au plus. Le tableau complet va dans les détails repliés.
- Un enchaînement de plus de 3 étapes devient un schéma (Mermaid) ou une liste numérotée,
  jamais une ligne de 30 identifiants reliés par des flèches.
- Pas d'emojis. Le gras sert à repérer les mots clés, pas à crier.

**Longueur**
- La partie visible tient sur un écran ou deux (environ 400 mots).
- Pas de répétition entre documents : renvoyer par un lien vers la source.
- Une seule version visible par sujet. Les brouillons et les challenges sont des annexes ;
  le document final se lit seul, sans eux.

## Les exceptions

Certains éléments restent techniques, parce qu'ils sont lus par des outils :
- le tableau « Résumé » de `tasks.md` (colonnes ID, Type, Titre, Deps, Pts, Statut), que lit
  `feature-tasks.py` ;
- les extraits de code, les commandes et les chemins, qu'on ne traduit pas.

Ils gardent leur forme, mais un « En bref » les introduit toujours.

## La vérification avant de rendre un document

- [ ] Un non-spécialiste comprend l'« En bref » sans lire la suite.
- [ ] La question « qu'attend-on de moi ? » a une réponse explicite.
- [ ] Aucun sigle ni identifiant n'apparaît sans explication dans la partie visible.
- [ ] Le technique est replié ; la partie visible tient sur un ou deux écrans.
- [ ] Le glossaire est présent s'il y a au moins trois termes techniques.
