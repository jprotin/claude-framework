---
name: typescript
description: Expert TypeScript (5.x). À invoquer pour typages avancés, generics, strict mode, migrations JS→TS, librairies publiques. Hérite des principes /javascript. Déclencheurs : "typescript", "ts", "tsconfig", "types", "generic", "zod".
---

# Skill : TypeScript (5.x)

Tu es expert TS. Tu utilises les types comme un outil, pas un fardeau.

> Ce skill complète `/javascript` — les règles JS s'appliquent aussi.

## `tsconfig.json` strict

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2023", "DOM"],

    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,

    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "skipLibCheck": true,

    "resolveJsonModule": true,
    "allowSyntheticDefaultImports": true,

    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

**Non négociables** : `strict: true`, `noUncheckedIndexedAccess: true`.

## Types de base — à maîtriser

### Unions, intersections, literals
```ts
type Status = "pending" | "done" | "failed";

type User = { id: number; name: string };
type Admin = User & { permissions: string[] };

type Id = string | number;
```

### `type` vs `interface`
- **`type`** : préféré par défaut (plus flexible : unions, conditionnels, mapped)
- **`interface`** : quand on veut du declaration merging / extension naturelle (surtout pour APIs publiques)

### Generics
```ts
function identity<T>(x: T): T {
  return x;
}

function first<T>(arr: T[]): T | undefined {
  return arr[0];
}

// Avec contraintes
function keyOf<T extends object, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}
```

### Utility types
```ts
Partial<User>          // toutes optionnelles
Required<User>         // toutes requises
Readonly<User>         // readonly
Pick<User, "id">       // garder certaines clés
Omit<User, "password"> // retirer certaines clés
Record<string, User>   // { [k: string]: User }
ReturnType<typeof fn>
Parameters<typeof fn>
Awaited<Promise<User>> // User
```

### Discriminated unions (exhaustive switch)
```ts
type Event =
  | { kind: "click"; x: number; y: number }
  | { kind: "scroll"; delta: number }
  | { kind: "keypress"; key: string };

function handle(e: Event) {
  switch (e.kind) {
    case "click":    return `clicked ${e.x},${e.y}`;
    case "scroll":   return `scrolled ${e.delta}`;
    case "keypress": return `pressed ${e.key}`;
    default:         { const _n: never = e; throw new Error(_n); }
  }
}
```

### Type guards
```ts
function isError(x: unknown): x is Error {
  return x instanceof Error;
}

function assertNonNull<T>(v: T): asserts v is NonNullable<T> {
  if (v == null) throw new Error("null");
}
```

### Template literal types (niveau avancé)
```ts
type HttpMethod = "GET" | "POST" | "PUT" | "DELETE";
type Route = `/api/${string}`;
type Endpoint = `${HttpMethod} ${Route}`;
```

### Mapped types
```ts
type Nullable<T> = { [K in keyof T]: T[K] | null };
type StringKeys<T> = { [K in keyof T]: T[K] extends string ? K : never }[keyof T];
```

## Règles d'or

- **Pas de `any`** → `unknown` si type inconnu puis narrowing
- **Pas de `as` cast** sauf si vraiment nécessaire (assertion de type = contrat non vérifié)
- **`readonly`** partout où applicable (array, props, fields)
- **Const assertions** : `as const` pour figer un literal
  ```ts
  const config = { env: "prod", port: 8080 } as const;
  // type: { readonly env: "prod"; readonly port: 8080 }
  ```
- **`satisfies`** (TS 4.9+) : valider sans perdre le type précis
  ```ts
  const routes = {
    home: "/",
    login: "/login",
  } satisfies Record<string, string>;
  // typeof routes.home = "/" (pas string)
  ```
- **Branded types** pour sémantique forte
  ```ts
  type UserId = number & { readonly __brand: "UserId" };
  function toUserId(n: number): UserId { return n as UserId; }
  ```

## Validation runtime — Zod

Pour valider des inputs externes (API, DB, form) :
```ts
import { z } from "zod";

const UserSchema = z.object({
  id: z.number().int().positive(),
  email: z.string().email(),
  role: z.enum(["admin", "user"]),
});

type User = z.infer<typeof UserSchema>;   // type déduit

// Usage
const user = UserSchema.parse(rawInput);   // throw si invalide
const result = UserSchema.safeParse(rawInput);   // { success, data } | { success, error }
```

**Règle** : au moindre doute sur la provenance (réseau, fichier, env), passer par Zod ou équivalent.

## Erreurs typées

```ts
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

async function fetchUser(id: number): Promise<Result<User>> {
  try {
    const user = await db.findUser(id);
    return { ok: true, value: user };
  } catch (err) {
    return { ok: false, error: err as Error };
  }
}

// Usage
const r = await fetchUser(1);
if (!r.ok) {
  log.error(r.error);
  return;
}
console.log(r.value.name);
```

## Générer types depuis schémas

- **OpenAPI → TS** : `openapi-typescript`
- **GraphQL → TS** : `@graphql-codegen/typescript`
- **SQL → TS** : Prisma, Drizzle, Kysely
- **JSON Schema → TS** : `json-schema-to-typescript`

## Red flags

- `any` partout (reculer sur `unknown` + narrowing)
- `as SomeType` au lieu de type guards
- `@ts-ignore` / `@ts-expect-error` sans commentaire expliquant
- Types de retour manquants sur fonctions publiques
- `noUncheckedIndexedAccess` désactivé
- Duplication de types manuellement maintenus (au lieu de dériver)
- Fichiers `.d.ts` écrits à la main pour du code qu'on contrôle
- Enums numériques non-const (préférer `const enum` ou unions de strings)
- `Object` / `Function` comme types (utiliser types précis)

## Learnings

<!-- Enrichi via /skill-enrich typescript -->
