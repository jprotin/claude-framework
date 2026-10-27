"""Hook MkDocs du hub /feature : tableau de bord, page « En ce moment » et kanban par projet.

Les pages sont générées en mémoire à chaque build (donc à chaque hot-reload) depuis :
  <projet>/<feature>/meta.json        étape, statut, `waiting_for` (ce qu'on attend de l'utilisateur)
  <projet>/<feature>/tasks/tasks.json statut de chaque task (écrit par bin/feature-tasks.py)
Rien n'est écrit dans les projets.
"""

from __future__ import annotations

import html
import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Any

from mkdocs.structure.files import File, Files
from mkdocs.structure.nav import Navigation, Section

PHASES = [
    ("spec", "Cadrage"),
    ("plan", "Conception"),
    ("decompose", "Découpage"),
    ("implement", "Développement"),
    ("validate", "Vérification"),
    ("document", "Documentation"),
]
FEATURE_STATUS = {"in-progress": "En cours", "done": "Terminée", "abandoned": "Abandonnée"}
COLUMNS = [("todo", "À faire"), ("doing", "En cours"), ("blocked", "Bloqué"), ("done", "Fait")]
KANBAN_PAGE = "kanban.md"
NOW_PAGE = "en-cours.md"

log = logging.getLogger("mkdocs.hooks.kanban")


def _read_json(path: Path) -> dict[str, Any] | None:
    """Objet JSON du fichier ; None si absent, illisible ou d'un autre type (signalé)."""
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        log.warning("Suivi illisible, ignoré : %s (%s)", path, error)
        return None
    if not isinstance(data, dict):
        log.warning("Suivi ignoré, objet JSON attendu : %s", path)
        return None
    return data


def _inline(text: Any) -> str:
    """Échappe le texte, en gardant le `code` Markdown lisible dans le HTML des cartes."""
    value = "" if text is None else str(text)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(value))


def _cell(text: Any) -> str:
    """Texte libre placé dans du Markdown (tableau, liste, admonition) : une seule ligne,
    sans `|` qui couperait la cellule ni lien Markdown (textes écrits par des agents)."""
    flat = re.sub(r"\s*\n\s*", " ", _inline(text))
    return flat.replace("|", "&#124;").replace("[", "&#91;").replace("]", "&#93;")


def _load_feature(meta_path: Path) -> dict[str, Any]:
    meta = _read_json(meta_path) or {}
    tasks_doc = _read_json(meta_path.parent / "tasks" / "tasks.json")
    raw_tasks = tasks_doc.get("tasks") if tasks_doc is not None else None
    tasks = [t for t in raw_tasks if isinstance(t, dict)] if isinstance(raw_tasks, list) else []
    return {
        "slug": meta_path.parent.name,
        "meta": meta,
        "tasks": tasks,
        "structured": isinstance(raw_tasks, list),
    }


def _load_features(docs_dir: Path) -> dict[str, list[dict[str, Any]]]:
    projects: dict[str, list[dict[str, Any]]] = {}
    for project_dir in sorted(p for p in docs_dir.iterdir() if p.is_symlink() and p.is_dir()):
        features = []
        for meta_path in sorted(project_dir.glob("*/meta.json")):
            features.append(_load_feature(meta_path))
        # Features actives d'abord, puis par date de démarrage la plus récente (tri stable).
        features.sort(key=lambda f: str(f["meta"].get("started", "")), reverse=True)
        features.sort(key=lambda f: f["meta"].get("status") != "in-progress")
        projects[project_dir.name] = features
    return projects


def _phase_label(meta: dict[str, Any]) -> str:
    status = meta.get("status", "")
    if status in ("done", "abandoned"):
        return FEATURE_STATUS[status]
    try:
        index = int(meta.get("current_phase", 1)) - 1
    except (TypeError, ValueError):
        index = 0
    index = min(max(index, 0), len(PHASES) - 1)
    return f"{index + 1}/6 · {PHASES[index][1]}"


def _column(task: dict[str, Any]) -> str:
    """Statut inconnu ou absent : la task reste visible, en « À faire »."""
    status = str(task.get("status", ""))
    return status if status in dict(COLUMNS) else "todo"


def _counts(tasks: list[dict[str, Any]]) -> dict[str, int]:
    counts = {key: 0 for key, _ in COLUMNS}
    for task in tasks:
        counts[_column(task)] += 1
    return counts


def _progress(tasks: list[dict[str, Any]]) -> str:
    if not tasks:
        return "—"
    done = _counts(tasks)["done"]
    percent = round(100 * done / len(tasks))
    return (
        f'<span class="fh-bar"><span style="width:{percent}%"></span></span> '
        f"{done}/{len(tasks)}"
    )


def _link(project: str, slug: str, from_root: bool) -> str:
    prefix = f"{project}/" if from_root else ""
    return f"[{slug}]({prefix}{slug}/index.md)"


def _waiting(feature: dict[str, Any]) -> list[str]:
    items = []
    if feature["meta"].get("waiting_for"):
        items.append(str(feature["meta"]["waiting_for"]))
    for task in feature["tasks"]:
        if task.get("waiting_for_user") and task.get("status") != "done":
            items.append(f'{task.get("id")} — {task.get("note") or task.get("title") or ""}')
    return items


def _dashboard(projects: dict[str, list[dict[str, Any]]]) -> str:
    lines = [
        "# Tableau de bord",
        "",
        f"Mis à jour le {datetime.now():%d/%m/%Y à %H:%M}. "
        "La page se rafraîchit toute seule quand une feature avance.",
        "",
    ]

    waiting = [
        (p, f, item)
        for p, feats in projects.items()
        for f in feats
        if f["meta"].get("status") == "in-progress"
        for item in _waiting(f)
    ]
    lines += ["## À vous de jouer", ""]
    if waiting:
        lines += [
            f"- **{p}** · {_link(p, f['slug'], True)} : {_cell(item)}" for p, f, item in waiting
        ]
    else:
        lines.append("Rien n'attend votre validation pour l'instant.")
    lines.append("")

    for project, features in projects.items():
        lines += [f"## {project}", "", f"[Voir le kanban]({project}/{KANBAN_PAGE})", ""]
        if not features:
            lines += ["_Aucune feature pour l'instant._", ""]
            continue
        lines += ["| Feature | Étape | Avancement | En cours | Bloqué |", "|---|---|---|---|---|"]
        for feature in features:
            counts = _counts(feature["tasks"])
            lines.append(
                f"| {_link(project, feature['slug'], True)} | {_phase_label(feature['meta'])} "
                f"| {_progress(feature['tasks'])} | {counts['doing'] or ''} "
                f"| {counts['blocked'] or ''} |"
            )
        lines.append("")
    return "\n".join(lines)


def _now_page(projects: dict[str, list[dict[str, Any]]]) -> str:
    lines = [
        "# En ce moment",
        "",
        "Ce qui avance, ce qui bloque, et ce qui attend votre Go — tous projets.",
        "",
    ]
    for title, status in (("En cours", "doing"), ("Bloqué", "blocked")):
        lines += [f"## {title}", ""]
        rows = [
            (p, f, t)
            for p, feats in projects.items()
            for f in feats
            for t in f["tasks"]
            if t.get("status") == status and f["meta"].get("status") == "in-progress"
        ]
        if not rows:
            lines += ["_Rien._", ""]
            continue
        lines += ["| Projet | Feature | Task | Précision |", "|---|---|---|---|"]
        lines += [
            f"| {p} | {_link(p, f['slug'], True)} | **{_cell(t.get('id'))}** "
            f"{_cell(t.get('title'))} | {_cell(t.get('note'))} |"
            for p, f, t in rows
        ]
        lines.append("")
    lines += ["## Attend votre Go", ""]
    waiting = [
        (p, f, item)
        for p, feats in projects.items()
        for f in feats
        if f["meta"].get("status") == "in-progress"
        for item in _waiting(f)
    ]
    lines += [f"- **{p}** · {_link(p, f['slug'], True)} : {_cell(i)}" for p, f, i in waiting] or [
        "_Rien._"
    ]
    return "\n".join(lines) + "\n"


def _card(task: dict[str, Any]) -> str:
    meta = " · ".join(_inline(task[k]) for k in ("group", "type") if task.get(k))
    note = f'<div class="fh-note">{_inline(task["note"])}</div>' if task.get("note") else ""
    flag = ' <span class="fh-go">attend votre Go</span>' if task.get("waiting_for_user") else ""
    return (
        f'<div class="fh-card"><div class="fh-id">{_inline(task.get("id"))}'
        f'{" · " + meta if meta else ""}{flag}</div>'
        f'<div>{_inline(task.get("title"))}</div>{note}</div>'
    )


def _board(tasks: list[dict[str, Any]]) -> str:
    columns = []
    for key, label in COLUMNS:
        cards = [t for t in tasks if _column(t) == key]
        body = "".join(_card(t) for t in cards)
        if key == "done" and len(cards) > 5:
            body = f"<details><summary>Voir les {len(cards)} tasks faites</summary>{body}</details>"
        columns.append(
            f'<div class="fh-col fh-{key}"><div class="fh-col-title">{label} '
            f"<span>{len(cards)}</span></div>{body}</div>"
        )
    return f'<div class="fh-board">{"".join(columns)}</div>'


def _kanban_page(project: str, features: list[dict[str, Any]]) -> str:
    lines = [f"# Kanban — {project}", ""]
    if not features:
        return "\n".join(lines + ["_Aucune feature pour l'instant._", ""])
    for feature in features:
        meta = feature["meta"]
        lines += [
            f"## {feature['slug']}",
            "",
            f"**Étape** : {_phase_label(meta)} · **Avancement** : {_progress(feature['tasks'])} · "
            f"{_link(project, feature['slug'], False)}",
            "",
        ]
        waiting = _waiting(feature) if meta.get("status") == "in-progress" else []
        if waiting:
            lines += ['!!! warning "Attend votre Go"', ""]
            lines += [f"    - {_cell(item)}" for item in waiting]
            lines.append("")
        if not feature["structured"]:
            lines += ["_Suivi non structuré : pas de `tasks/tasks.json` pour cette feature._", ""]
            continue
        board = _board(feature["tasks"])
        if meta.get("status") in ("done", "abandoned"):
            board = f"<details><summary>Afficher le tableau</summary>{board}</details>"
        lines += [board, ""]
    return "\n".join(lines)


def _safe_page(title: str, build: Any, *args: Any) -> str:
    """Une donnée inattendue ne doit pas faire tomber tout le hub : page d'erreur à la place."""
    try:
        return str(build(*args))
    except Exception:
        log.exception("Page « %s » non générée", title)
        return f"# {title}\n\n_Suivi illisible : voir le terminal de feature-serve._\n"


def on_files(files: Files, config: Any) -> Files:
    docs_dir = Path(config["docs_dir"])
    projects = _load_features(docs_dir)
    pages = {
        "index.md": _safe_page("Tableau de bord", _dashboard, projects),
        NOW_PAGE: _safe_page("En ce moment", _now_page, projects),
    }
    for project, features in projects.items():
        pages[f"{project}/{KANBAN_PAGE}"] = _safe_page(
            f"Kanban — {project}", _kanban_page, project, features
        )
    for src_uri, content in pages.items():
        existing = files.get_file_from_path(src_uri)
        if existing is not None:
            files.remove(existing)
        files.append(File.generated(config, src_uri, content=content))
    return files


def on_nav(nav: Navigation, config: Any, files: Files) -> Navigation:
    """Place le kanban en première page de chaque onglet projet."""
    for item in nav.items:
        if isinstance(item, Section):
            kanban = [
                c
                for c in item.children
                if getattr(getattr(c, "file", None), "src_uri", "") == f"{item.title}/{KANBAN_PAGE}"
            ]
            if kanban:
                item.children.remove(kanban[0])
                item.children.insert(0, kanban[0])
    return nav
