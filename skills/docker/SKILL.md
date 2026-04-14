---
name: docker
description: Expert Docker / conteneurisation. À invoquer pour écrire Dockerfiles, docker-compose, optimiser images, sécuriser, debug runtime. Déclencheurs : "docker", "dockerfile", "image", "container", "compose".
---

# Skill : Docker

Tu es expert Docker. Tu écris des images petites, sûres, reproductibles.

## Dockerfile best practices

### Multi-stage obligatoire (app)
```dockerfile
# Stage 1 : builder
FROM node:20.11-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.pnpm-store \
    corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

# Stage 2 : runtime (minimal)
FROM node:20.11-alpine AS runtime
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app

COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --from=builder --chown=app:app /app/dist ./dist
COPY --from=builder --chown=app:app /app/package.json ./

USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

### Règles d'or
- **Image de base pinnée** (tag précis + digest idéalement) : `FROM node:20.11-alpine@sha256:...`
- **User non-root** : `USER app` après avoir créé l'utilisateur
- **Minimal runtime** : alpine, distroless, scratch selon tolérance
- **Layer caching** : ordre `COPY deps + install` → `COPY source + build`
- **`.dockerignore`** rigoureux (pas de `.git/`, `node_modules/`, `.env`, etc.)
- **`HEALTHCHECK`** défini
- **`EXPOSE`** documentaire (pas fonctionnel)
- **`ENV`** pas pour les secrets (visibles dans `docker history`)

### `.dockerignore` minimum
```
.git
.gitignore
.github
.vscode
.idea
node_modules
dist
build
coverage
.env
.env.*
!.env.example
*.md
!README.md
Dockerfile
docker-compose*.yml
.dockerignore
tests
*.test.*
```

## Build optimisé

### BuildKit (défaut moderne)
```bash
DOCKER_BUILDKIT=1 docker build .
# ou
docker buildx build .
```

### Cache mount (évite de re-télécharger deps)
```dockerfile
RUN --mount=type=cache,target=/root/.npm \
    npm ci
```

### Secret mount (build-time)
```dockerfile
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci
```
```bash
docker build --secret id=npm_token,src=$HOME/.npm_token .
```

### Build multi-plateforme
```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:1.0 --push .
```

## Sécurité image

- **Scan** : `trivy image myapp:1.0` ou `docker scout cves myapp:1.0`
- **Signature** : `cosign sign` sur le registry
- **SBOM** : `syft myapp:1.0 -o cyclonedx-json`
- **Minimise la surface** : distroless, pas de shell, pas de package manager au runtime
- **Pas de secrets** dans ARG/ENV (visibles dans `docker history`)
- **Capabilities** réduites au runtime : `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`
- **Read-only rootfs** : `--read-only` + volumes pour écritures nécessaires

## Compose (dev / stacks simples)

```yaml
services:
  api:
    build:
      context: .
      target: runtime
    image: myapp:${VERSION:-dev}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://app:${DB_PASSWORD}@db:5432/app
    secrets:
      - db_password
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 3s
      retries: 3
    deploy:
      resources:
        limits: { memory: 512M }

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: app
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    volumes:
      - db-data:/var/lib/postgresql/data
    secrets:
      - db_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s

volumes:
  db-data:

secrets:
  db_password:
    file: ./secrets/db_password
```

## Networking

- Un réseau par stack compose, pas `default` partagé
- Jamais de `network_mode: host` sauf cas précis (performance réseau, découverte mDNS)
- Services internes sur réseau interne, Traefik/nginx en frontal

## Logging

- `json-file` driver avec rotation :
```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```
- En prod : driver `syslog`, `gelf`, `journald`, ou sidecar qui ship vers Loki/ELK

## Debugging runtime

```bash
docker ps
docker logs <ctr> -f --tail 100
docker exec -it <ctr> sh
docker inspect <ctr> | jq '.[0].State'
docker top <ctr>
docker stats

# Dans un container distroless sans shell
docker run --rm -it --pid=container:<ctr> --net=container:<ctr> \
  --cap-add SYS_PTRACE nicolaka/netshoot
```

## Red flags

- `FROM ubuntu:latest` → jamais `latest`, toujours version
- `RUN apt-get install ... && rm -rf /var/lib/apt/lists/*` **pas** sur la même ligne
- `COPY . .` sans `.dockerignore` rigoureux
- Conteneur qui tourne en root
- `docker run --privileged`
- Secrets en `ENV` ou `ARG` (vus dans history/inspect)
- Pas de HEALTHCHECK
- Image > 1 Go pour une app node/python simple
- Un conteneur = plusieurs services (multi-process sans superviseur)
- `docker-compose.yml` versionné en prod (`docker compose` n'est pas un orchestrateur prod robuste)

## Outils qualité

- **`hadolint`** : Dockerfile linter (pre-commit intégré)
- **`dive`** : analyse des layers, gaspillage d'espace
- **`trivy`** / **`docker scout`** : CVE + config scan
- **`syft`** / **`grype`** : SBOM + vulns

## Learnings

<!-- Enrichi via /skill-enrich docker -->
