---
name: python
description: Expert Python. À invoquer pour écrire code Python moderne (3.10+), typing, packaging, testing, async, patterns. Déclencheurs : "python", "pip", "pytest", "pyproject", "venv", "uv".
---

# Skill : Python (3.10+)

Tu es expert Python senior. Tu écris du code typé, testé, idiomatique.

## Stack moderne (2026)

- **Python 3.10+** (3.11 / 3.12 préférés)
- **Packaging** : `pyproject.toml` (PEP 621), `hatchling` ou `setuptools` comme backend
- **Gestion deps** : `uv` (rapide, moderne) ou `poetry`
- **Virtualenv** : `uv venv` ou `python -m venv`
- **Formatage + lint** : `ruff` (remplace black, flake8, isort, pyupgrade)
- **Type check** : `mypy` en `strict` mode, ou `pyright`
- **Test** : `pytest` + plugins (`pytest-cov`, `pytest-asyncio`, `pytest-mock`)

## `pyproject.toml` minimal

```toml
[project]
name = "myapp"
version = "0.1.0"
description = "…"
readme = "README.md"
requires-python = ">=3.11"
authors = [{name = "..."}]
dependencies = [
  "httpx>=0.27",
  "pydantic>=2.5",
]

[project.optional-dependencies]
dev = [
  "ruff>=0.7",
  "mypy>=1.13",
  "pytest>=8",
  "pytest-cov",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "N", "UP", "B", "SIM", "RUF", "TCH"]
ignore = []

[tool.mypy]
strict = true
python_version = "3.11"

[tool.pytest.ini_options]
addopts = "-ra --cov=myapp --cov-report=term-missing"
testpaths = ["tests"]
```

## Type hints — obligatoires

```python
from collections.abc import Iterable, Mapping

def parse(items: Iterable[str]) -> list[int]:
    return [int(x) for x in items]

def config(key: str, default: str | None = None) -> str:
    ...
```

**Règles** :
- Types sur fonctions publiques (signatures + retour)
- Préférer `list[int]` à `List[int]` (3.9+)
- `|` pour unions (`str | None`), pas `Optional[str]`
- `collections.abc` pour les protocols (`Iterable`, `Mapping`)
- `TypeAlias`, `NewType` pour sémantique

## Idiomatique

### Dataclasses / Pydantic
```python
from dataclasses import dataclass, field
from typing import Self

@dataclass(slots=True, frozen=True)
class User:
    id: int
    name: str
    tags: list[str] = field(default_factory=list)

    @classmethod
    def from_row(cls, row: dict) -> Self:
        return cls(id=row["id"], name=row["name"])
```

Pour validation runtime + parsing JSON → **Pydantic v2**.

### Comprehensions > boucles verbose
```python
# Bon
users_by_id = {u.id: u for u in users}
active = [u for u in users if u.active]

# Moyen
result = {}
for u in users:
    result[u.id] = u
```

### f-strings partout
```python
log.info(f"Processing user={user.id} action={action}")
```

### Context managers
```python
with open(path, encoding="utf-8") as f:
    data = f.read()

# Custom
from contextlib import contextmanager

@contextmanager
def timer(name: str):
    start = time.perf_counter()
    try:
        yield
    finally:
        log.info(f"{name}: {time.perf_counter() - start:.3f}s")
```

### Async
```python
import asyncio
import httpx

async def fetch_all(urls: list[str]) -> list[str]:
    async with httpx.AsyncClient() as client:
        return await asyncio.gather(*(fetch(client, u) for u in urls))

async def fetch(client: httpx.AsyncClient, url: str) -> str:
    r = await client.get(url, timeout=10)
    r.raise_for_status()
    return r.text
```

## Testing (pytest)

```python
# tests/test_users.py
import pytest
from myapp.users import User, create_user

@pytest.fixture
def sample_user() -> User:
    return User(id=1, name="Alice")

def test_create_user(sample_user: User) -> None:
    assert sample_user.name == "Alice"

@pytest.mark.parametrize("name,expected", [
    ("alice", True),
    ("", False),
])
def test_is_valid_name(name: str, expected: bool) -> None:
    assert is_valid_name(name) is expected

@pytest.mark.asyncio
async def test_async_fetch() -> None:
    result = await fetch_user(1)
    assert result.id == 1
```

**Conventions** :
- Un fichier de test par module (`tests/test_<module>.py`)
- Fixtures partagées dans `conftest.py`
- AAA : Arrange / Act / Assert
- Test names : `test_<action>_<condition>_<expected>`
- Coverage minimum 70%, 90% sur code critique
- Pas de `mock` quand on peut tester en vrai (via fixture)

## Structure projet

```
myapp/
├── pyproject.toml
├── README.md
├── src/
│   └── myapp/
│       ├── __init__.py
│       ├── cli.py
│       ├── config.py
│       ├── models/
│       └── services/
├── tests/
│   ├── conftest.py
│   └── test_*.py
└── docs/
```

**Préférer** `src/myapp/` layout (évite les imports ambigus).

## Packaging / publication

```bash
# Build
uv build               # ou python -m build
# Artefacts dans dist/

# Publier
uv publish             # ou twine upload dist/*
```

## Performance

- **Mesurer** : `cProfile`, `py-spy`, `scalene`
- Pas d'optimisation avant profiling
- Éviter overhead : `__slots__` sur classes très instanciées
- I/O-bound → async ; CPU-bound → multiprocessing ou Cython/Rust
- Cache : `functools.lru_cache`, `@cache` (3.9+)

## Red flags

- `from X import *`
- Mutable default args (`def f(x=[])`)
- `except:` nu ou `except Exception:` sans relever
- Strings concat avec `+` en boucle (quadratique)
- `print` au lieu de `logging`
- Globals non constants
- `time.sleep()` dans code async
- Dépendances pas pinnées
- `setup.py` legacy (utiliser `pyproject.toml`)
- Code non typé en 2026 (mypy doit passer)

## Commandes cheatsheet

```bash
# uv
uv venv                    # crée .venv
uv pip install -e ".[dev]"
uv sync
uv run pytest

# Lint / format / types
ruff check . --fix
ruff format .
mypy src/

# Tests
pytest -x -v
pytest --cov=myapp --cov-report=html
pytest -k "test_users"
pytest --lf         # last failed
```

## Learnings

<!-- Enrichi via /skill-enrich python -->
