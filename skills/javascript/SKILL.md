---
name: javascript
description: Expert JavaScript moderne (ES2023+). À invoquer pour Node.js, navigateur, async, patterns, packaging. Pour TypeScript, utiliser /typescript. Déclencheurs : "javascript", "js", "node", "npm", "pnpm", "vite", "eslint".
---

# Skill : JavaScript moderne

Tu es expert JS senior. Tu écris du code moderne, testé, performant.

## Stack recommandée (2026)

- **Node.js** : LTS actuelle (20.x / 22.x)
- **Package manager** : `pnpm` > `npm` (rapide, strict, disk efficient)
- **Module system** : **ESM** (`"type": "module"` dans `package.json`)
- **Bundler** : `vite` (lib/app), `tsup`/`rollup` (lib)
- **Test** : `vitest` (moderne, rapide) ou `node --test` (built-in)
- **Lint** : `eslint` (flat config) + `prettier`

## `package.json` moderne

```json
{
  "name": "myapp",
  "version": "1.0.0",
  "type": "module",
  "engines": {
    "node": ">=20.11"
  },
  "main": "./dist/index.js",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  },
  "scripts": {
    "build": "vite build",
    "dev": "vite",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint .",
    "format": "prettier --write ."
  },
  "dependencies": {},
  "devDependencies": {}
}
```

## Idiomatique ES2023+

### Destructuring / spread
```js
const { name, age = 18, ...rest } = user;
const items = [...base, newItem];
const config = { ...defaults, ...overrides };
```

### Optional chaining + nullish
```js
const city = user?.address?.city ?? "Unknown";
const items = response?.data?.items ?? [];
```

### `const` > `let` > ~~`var`~~
```js
const users = [...];        // par défaut
let counter = 0;            // si mutation nécessaire
// var : jamais
```

### Array methods
```js
// Préférer
users.filter(u => u.active).map(u => u.email)
users.find(u => u.id === 42)
users.some(u => u.admin)
users.every(u => u.verified)
users.reduce((acc, u) => acc + u.score, 0)

// À oublier
for (let i = 0; i < users.length; i++) { ... }
```

### Async / await (jamais callbacks)
```js
async function fetchUsers() {
  try {
    const res = await fetch("/api/users");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    logger.error("fetchUsers failed", { err });
    throw err;
  }
}

// Parallèle
const [users, posts] = await Promise.all([fetchUsers(), fetchPosts()]);

// Settled (ne pas fail si un élément échoue)
const results = await Promise.allSettled(promises);
```

### Modules
```js
// named exports
export function foo() {}
export const bar = 42;

// default (éviter sauf React components / une seule chose exposée)
export default function Page() {}

// Imports
import { foo, bar } from "./utils.js";
import { readFile } from "node:fs/promises";   // préfixe node: explicite
```

### Classes (quand justifié)
```js
class UserService {
  #db;   // private field (#)

  constructor(db) {
    this.#db = db;
  }

  async getUser(id) {
    return this.#db.query("SELECT * FROM users WHERE id = $1", [id]);
  }
}
```
**Règle** : préférer fonctions + closures sauf si vraiment état encapsulé.

## Erreurs

```js
// Erreur custom
class ValidationError extends Error {
  constructor(message, field) {
    super(message);
    this.name = "ValidationError";
    this.field = field;
  }
}

// Usage
try {
  validate(input);
} catch (err) {
  if (err instanceof ValidationError) {
    return res.status(400).json({ error: err.message, field: err.field });
  }
  throw err;   // inconnue, remonte
}
```

**Règles** :
- Jamais `throw "string"` → toujours un `Error`
- `.cause` pour wrapper : `new Error("context", { cause: err })`
- Logger + rethrow ou logger + handle, pas les deux silencieusement

## Node.js — built-ins modernes (à utiliser avant de npm install)

```js
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createServer } from "node:http";
import { parseArgs } from "node:util";   // parser CLI
import { test, describe } from "node:test";   // test runner
import { setTimeout } from "node:timers/promises";
import { styleText } from "node:util";   // couleurs terminal
```

## Testing (vitest)

```js
import { describe, it, expect, beforeEach, vi } from "vitest";
import { UserService } from "./users.js";

describe("UserService", () => {
  let db;
  let service;

  beforeEach(() => {
    db = { query: vi.fn() };
    service = new UserService(db);
  });

  it("returns user by id", async () => {
    db.query.mockResolvedValue([{ id: 1, name: "Alice" }]);
    const user = await service.getUser(1);
    expect(user.name).toBe("Alice");
    expect(db.query).toHaveBeenCalledOnce();
  });
});
```

## Performance

- **Measure** : Chrome DevTools Performance, `node --inspect`, `clinic.js`
- Éviter re-render inutiles (React : `memo`, `useMemo`)
- Lazy load : `import()` dynamique pour chunks non-critiques
- Streaming > buffering pour gros fichiers/responses
- `structuredClone()` > `JSON.parse(JSON.stringify())`

## Sécurité

- **Jamais** `eval()` / `Function()` avec input utilisateur
- **Sanitize** : DOMPurify pour HTML, escape systématique
- **CSP** strict sur les apps web
- Headers sécurité : `helmet` (Express) / `@fastify/helmet`
- Deps : `npm audit`, Dependabot/Renovate
- Pas de secrets dans le code / `.env` pas committé

## Red flags

- `var` au lieu de `let`/`const`
- `==` au lieu de `===`
- Callbacks imbriqués (callback hell) — convertir en async/await
- Pas de gestion d'erreur async
- Dépendances jamais mises à jour (CVE accumulées)
- `JSON.parse` sans try/catch sur input externe
- `console.log` en prod (utiliser logger structuré)
- Tester uniquement le happy path
- Promesses chainées au lieu de `await`
- Node.js < LTS actuelle

## Learnings

<!-- Enrichi via /skill-enrich javascript -->
