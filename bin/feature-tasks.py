#!/usr/bin/env python3
"""feature-tasks.py — Suivi structuré des tasks d'une feature (source du kanban du hub web).

Usage:
  feature-tasks.py import  <feature-dir> [--force]               tasks.md → tasks/tasks.json
  feature-tasks.py set     <feature-dir> <id> <todo|doing|blocked|done> [--note TXT] [--go|--no-go]
  feature-tasks.py waiting <feature-dir> [texte]                 ce qu'on attend de l'utilisateur
                                                                 (meta.json ; sans texte : efface)
  feature-tasks.py show    <feature-dir>                         résumé des statuts

`set` sans --note efface la note quand le statut change ; sans --go, il retire le drapeau
« attend votre Go » (le Go est réputé donné).

`import` lit le tableau résumé de tasks/tasks-final.md (sinon tasks/tasks.md) : colonnes
reconnues par leur en-tête (ID, Titre, Statut, Type, Lot/Phase, Pts, Deps). Il n'écrase
jamais un tasks.json existant sans --force et signale les statuts qu'il n'a pas su lire.
Si l'implémentation est terminée (meta.json), les tasks restées ouvertes passent en done
avec la note « déduit » : les tableaux n'étaient pas toujours tenus à jour.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import sys
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Any, NoReturn

STATUSES = ("todo", "doing", "blocked", "done")
ID_PATTERN = re.compile(r"^[A-Za-z]+-?\d+[a-z]?$")
# « Go » en majuscule seulement : « go » désigne aussi le langage.
WAITING_PATTERN = re.compile(
    r"\bGo\b|(?i:validation utilisateur|attente (?:de l'|du |d')?(?:utilisateur|go|arbitrage))"
)
COLUMN_ALIASES = {
    "id": ("id",),
    "title": ("titre", "title", "tâche", "task"),
    "status": ("statut", "status", "état"),
    "type": ("type",),
    "group": ("lot", "phase"),
    "points": ("pts", "points", "est.", "est. (j-h)", "estimation"),
    "depends_on": ("deps", "dépend de", "dépendances"),
}
STATUS_PREFIXES = (
    ("done", ("done", "fait", "terminé", "terminée", "ok")),
    ("doing", ("in-progress", "in progress", "en cours", "doing", "wip")),
    ("blocked", ("blocked", "bloqué", "bloquée")),
    ("todo", ("pending", "todo", "à faire", "reporté", "reportée", "not started")),
)


def now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def die(message: str) -> NoReturn:
    print(f"[feature-tasks] {message}", file=sys.stderr)
    sys.exit(1)


def read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        die(f"Introuvable : {path}")
    except ValueError as error:
        die(f"JSON invalide : {path} ({error})")
    if not isinstance(data, dict):
        die(f"Objet JSON attendu : {path}")
    return data


def write_json(path: Path, data: dict[str, Any]) -> None:
    """Écriture atomique ; temporaire caché, que le hot-reload de MkDocs ignore."""
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


@contextmanager
def locked(feature_dir: Path) -> Iterator[None]:
    """Sérialise les lecture-modification-écriture concurrentes d'une même feature."""
    with open(feature_dir / ".feature-tasks.lock", "w", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def cells(line: str) -> list[str]:
    """Cellules d'une ligne de tableau ; `\\|` reste un caractère du contenu."""
    parts = re.split(r"(?<!\\)\|", line.strip().strip("|"))
    return [c.strip().replace("\\|", "|") for c in parts]


def map_columns(header: list[str]) -> dict[str, int]:
    mapping = {}
    for index, name in enumerate(h.lower() for h in header):
        for key, aliases in COLUMN_ALIASES.items():
            if key not in mapping and (name in aliases or name.startswith(aliases)):
                mapping[key] = index
    return mapping


def parse_status(raw: str) -> tuple[str | None, str]:
    """« done (poussé ; PR à ouvrir) » → ("done", "poussé ; PR à ouvrir")."""
    text = raw.strip()
    lowered = text.lower()
    for status, prefixes in STATUS_PREFIXES:
        for prefix in sorted(prefixes, key=len, reverse=True):
            # Mot entier : « fait partiellement » ne doit pas devenir done.
            if re.match(rf"{re.escape(prefix)}(?!\w)", lowered) and not re.match(
                rf"{re.escape(prefix)}\s+partiel", lowered
            ):
                note = text[len(prefix) :].strip().lstrip("-—–: ").strip()
                if note.startswith("(") and note.endswith(")"):
                    note = note[1:-1].strip()
                if prefix.startswith("report"):
                    note = f"reportée {note}".strip()
                return status, note
    return None, text


def parse_tasks(markdown: str) -> tuple[list[dict[str, Any]], bool, list[str]]:
    """Tasks des tableaux qui ont au moins les colonnes ID et Titre.

    Renvoie (tasks, colonne Statut vue, avertissements). Un ID présent dans plusieurs
    tableaux (résumé puis détail) garde sa première ligne, complétée par les suivantes.
    """
    tasks: dict[str, dict[str, Any]] = {}
    warnings: list[str] = []
    has_status = False
    columns: dict[str, int] | None = None
    heading_group = ""
    for line in markdown.splitlines():
        heading = re.match(r"^#{1,3}\s+(Lot\s+\S+)", line)
        if heading:
            heading_group = heading.group(1).rstrip(" —-:")
        if not line.lstrip().startswith("|"):
            columns = None
            continue
        row = cells(line)
        if columns is None:
            candidate = map_columns(row)
            if "id" in candidate and "title" in candidate and row[candidate["id"]].lower() == "id":
                columns = candidate
                has_status = has_status or "status" in columns
            continue
        if set("".join(row)) <= set("-: "):
            continue
        task_id = (row[columns["id"]] if columns["id"] < len(row) else "").strip("*`_ ")
        if not ID_PATTERN.match(task_id):
            if task_id:
                warnings.append(f"ligne ignorée, ID non reconnu : « {task_id} »")
            continue

        def cell(key: str) -> str:
            index = columns.get(key)
            return row[index] if index is not None and index < len(row) else ""

        deps = [
            d.strip("*`_")
            for d in re.split(r"[,;\s]+", cell("depends_on"))
            if ID_PATTERN.match(d.strip("*`_"))
        ]
        row_task = {
            "id": task_id,
            "title": cell("title"),
            "status_raw": cell("status"),
            "group": cell("group") or heading_group,
            "type": cell("type"),
            "points": cell("points"),
            "depends_on": deps,
        }
        if task_id in tasks:
            first = tasks[task_id]
            if row_task["status_raw"] and first["status_raw"] not in ("", row_task["status_raw"]):
                warnings.append(
                    f"{task_id} en double avec deux statuts, premier gardé : "
                    f"« {first['status_raw']} » (ignoré : « {row_task['status_raw']} »)"
                )
            for key, value in row_task.items():
                first[key] = first[key] or value
        else:
            tasks[task_id] = row_task
    return list(tasks.values()), has_status, warnings


def cmd_import(feature_dir: Path, force: bool) -> None:
    target = feature_dir / "tasks" / "tasks.json"
    if target.exists() and not force:
        die(f"{target} existe déjà (--force pour le régénérer : les statuts saisis seront perdus)")
    source = next(
        (
            p
            for p in (feature_dir / "tasks" / "tasks-final.md", feature_dir / "tasks" / "tasks.md")
            if p.exists()
        ),
        None,
    )
    if source is None:
        die(f"Pas de tasks/tasks.md dans {feature_dir}")
    meta = read_json(feature_dir / "meta.json")
    # Feature terminée : les tableaux n'ont pas toujours été tenus à jour pendant l'implémentation.
    phases = meta.get("phases")
    phases = phases if isinstance(phases, dict) else {}
    implement = phases.get("implement")
    implement = implement if isinstance(implement, dict) else {}
    implemented = meta.get("status") == "done" or implement.get("status") == "done"

    parsed, has_status, warnings = parse_tasks(source.read_text(encoding="utf-8"))
    if not parsed:
        die(f"Aucun tableau de tasks reconnu dans {source} (colonnes ID et Titre attendues)")
    unread = []
    tasks = []
    for item in parsed:
        raw = item.pop("status_raw")
        if has_status:
            parsed_status, note = parse_status(raw) if raw else ("todo", "")
            status = parsed_status or "todo"
        else:
            parsed_status, status, note = "todo", "todo", ""
        if implemented and status in ("todo", "doing"):
            status, note = "done", "déduit : implémentation terminée"
        task = {k: v for k, v in item.items() if v}
        task["status"] = status
        if note:
            task["note"] = note
        if note and status != "done" and WAITING_PATTERN.search(note):
            task["waiting_for_user"] = True
        if parsed_status is None and status == "todo":
            unread.append(f"{item['id']} : « {raw} »")
        tasks.append(task)

    write_json(target, {"version": 1, "source": source.name, "updated": now(), "tasks": tasks})
    counts = {s: sum(t["status"] == s for t in tasks) for s in STATUSES}
    print(
        f"[feature-tasks] {target} : {len(tasks)} tasks "
        + ", ".join(f"{s} {n}" for s, n in counts.items())
    )
    if not has_status:
        print("[feature-tasks] pas de colonne Statut dans le tableau")
    deduced = sum(t.get("note", "").startswith("déduit") for t in tasks)
    if deduced:
        print(
            f"[feature-tasks] {deduced} task(s) passées en done par déduction (implémentation terminée)"
        )
    for line in unread:
        print(f"[feature-tasks] statut non reconnu, mis en todo — {line}")
    for line in warnings:
        print(f"[feature-tasks] {line}")


def cmd_set(
    feature_dir: Path, task_id: str, status: str, note: str | None, go: bool | None
) -> None:
    path = feature_dir / "tasks" / "tasks.json"
    data = read_json(path)
    task = next((t for t in data.get("tasks", []) if t.get("id") == task_id), None)
    if task is None:
        die(f"Task {task_id} absente de {path}")
    if note:
        task["note"] = note
    elif note is not None or task.get("status") != status:
        task.pop("note", None)  # ex. la raison d'un blocage n'a plus de sens une fois débloqué
    task["status"] = status
    if go and status != "done":
        task["waiting_for_user"] = True
    else:
        task.pop("waiting_for_user", None)
    task["updated"] = data["updated"] = now()
    write_json(path, data)
    print(f"[feature-tasks] {task_id} → {status}")


def cmd_waiting(feature_dir: Path, text: str) -> None:
    path = feature_dir / "meta.json"
    meta = read_json(path)
    if text:
        meta["waiting_for"] = text
    else:
        meta.pop("waiting_for", None)
    write_json(path, meta)
    print(f"[feature-tasks] attente utilisateur : {text or '(aucune)'}")


def cmd_show(feature_dir: Path) -> None:
    data = read_json(feature_dir / "tasks" / "tasks.json")
    for status in STATUSES:
        ids = [t["id"] for t in data.get("tasks", []) if t.get("status") == status]
        print(f"{status:8} {len(ids):3}  {' '.join(ids) if status != 'done' else ''}".rstrip())


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = parser.add_subparsers(dest="command", required=True)
    p_import = sub.add_parser("import")
    p_import.add_argument("feature_dir", type=Path)
    p_import.add_argument("--force", action="store_true")
    p_set = sub.add_parser("set")
    p_set.add_argument("feature_dir", type=Path)
    p_set.add_argument("task_id")
    p_set.add_argument("status", choices=STATUSES)
    p_set.add_argument("--note")
    go = p_set.add_mutually_exclusive_group()
    go.add_argument(
        "--go", dest="go", action="store_true", default=None, help="attend le Go utilisateur"
    )
    go.add_argument("--no-go", dest="go", action="store_false")
    p_waiting = sub.add_parser("waiting")
    p_waiting.add_argument("feature_dir", type=Path)
    p_waiting.add_argument("text", nargs="*")
    p_show = sub.add_parser("show")
    p_show.add_argument("feature_dir", type=Path)
    args = parser.parse_args()

    if not (args.feature_dir / "meta.json").exists():
        die(f"{args.feature_dir} n'est pas une feature (meta.json absent)")
    with locked(args.feature_dir):
        if args.command == "import":
            cmd_import(args.feature_dir, args.force)
        elif args.command == "set":
            cmd_set(args.feature_dir, args.task_id, args.status, args.note, args.go)
        elif args.command == "waiting":
            cmd_waiting(args.feature_dir, " ".join(args.text))
        else:
            cmd_show(args.feature_dir)


if __name__ == "__main__":
    main()
