# Gratheon monorepo

Entry point for local development of [Gratheon](https://gratheon.com): how the services fit together, which ports they use, and cross-service UI tests.
Each service lives in its own repository, checked out next to this one:

```
~/git/gratheon/
  monorepo/            <- this repo
  schema-registry/     (Gratheon/graphql-schema-registry)
  graphql-router/
  swarm-api/
  image-splitter/
  user-cycle/
  web-app/
  ...
```

## Stack

| Layer | Technology |
|---|---|
| Storage | PostgreSQL 18 (one database per service), Redis 8 (pub/sub, cache), MinIO (S3-compatible, local only) |
| API gateway | Apollo-federated GraphQL: `graphql-router` composes the supergraph from schemas registered in `schema-registry` |
| Backend | Go (swarm-api, gate-video-stream), Node.js/TypeScript (user-cycle, image-splitter, event-stream-filter, telemetry-api, ...) |
| ML models | Python services (bee, queen, varroa, frame resources detectors) |
| Frontend | web-app: Preact + Vite + urql, also packaged as Tauri desktop app and Android TWA |
| Observability | OpenTelemetry -> ClickStack (ClickHouse + HyperDX) |
| Tests | Unit tests per repo, Playwright UI tests in `e2e/` here |

MySQL and InfluxDB are no longer used.

All service compose files join one docker network `gratheon_default`, so always run them with `COMPOSE_PROJECT_NAME=gratheon`.
Containers talk to each other by service name (`postgres:5432`, `redis:6379`, `swarm-api:8100`, ...); host ports below are for the browser and debugging only.

## Ports

Host ports published by the `docker-compose.dev.yml` of each repo.

### Storage - 5xxx
| Service | Port | Notes |
|---|---|---|
| postgres (`dev-env/`) | 5433 | user/password `test`/`test`, databases created by `dev-env/postgres-init` |
| redis (`dev-env/`) | 6383 | password `pass` |
| minio (image-splitter) | 19000 | S3 API; console on 9001 only in image-splitter `docker-compose.test.yml` |

5432/6379 are left free on purpose, other local projects usually occupy them.

### Router - 6xxx
| Service | Port |
|---|---|
| schema-registry | 6001 (UI + API), 6002 (internal) |
| graphql-router | 6100 - web-app talks to `http://localhost:6100/graphql` |

### Backend - 4xxx, 8xxx
| Service | Port |
|---|---|
| user-cycle | 4000 |
| weather | 8070 |
| swarm-api | 8100 |
| event-stream-filter | 8300 (http), 8350 (websocket subscriptions) |
| telemetry-api | 8600 |
| image-splitter | 8800 |
| gate-video-stream | 8900, 8950 |
| plantnet | 8090 (unused) |
| alerts | 4560 |
| entrance-observer | 3030 |

### ML models - 87xx
| Service | Port |
|---|---|
| models-frame-resources | 8540 |
| models-bee-detector | 8700 (+ 8126) |
| models-queen-bee-detector | 8710 |
| models-varroa-on-bee | 8752 |

### Frontend
| Service | Port |
|---|---|
| web-app (vite dev server) | 8080 |

### Observability
| Service | Port |
|---|---|
| clickstack OTLP collector | 4317 (grpc), 4318 (http) - services export to `host.docker.internal:4318` |
| clickstack HyperDX UI | 8081 |
| clickstack ClickHouse | 8123, 9001 |
| grafana (legacy) | 9000 |

Known overlaps: `rate-limiter` publishes 6380-6382, clickstack ClickHouse (9001) and image-splitter test minio console (9001) cannot run together.

## Running locally

Requirements: Docker, [just](https://github.com/casey/just), nvm (Node 24 for most repos, web-app needs Node 26 from its `.nvmrc`).

```sh
make start-storage   # postgres + redis from dev-env/
make start-router    # schema-registry, then graphql-router
make start-be        # swarm-api (with migrations), image-splitter, user-cycle
make start-fe        # web-app on http://localhost:8080
```

or everything at once with `make start`. Stop with `make stop`.

Local config files are gitignored in each repo and must be created once with `make init-configs` (`dev-env/init-configs.sh`, existing files are kept):

| Repo | File | Based on |
|---|---|---|
| schema-registry | `docker-compose.gratheon.yml` | `dev-env/schema-registry/docker-compose.gratheon.yml`; points to the shared postgres/redis |
| swarm-api | `config/config.dev.json` | `config/config.example.json` + JWT key (user-cycle dev `JWT_KEY`, or `JWT_KEY` env) |
| image-splitter | `src/config/config.dev.ts` | `config.default.ts`, postgres ssl disabled |
| user-cycle | `src/config/config.dev.ts` | `config.default.ts`, postgres ssl disabled |

Not started by default: event-stream-filter (subscriptions / live updates), ML models (photo detection), telemetry-api, clickstack (OTLP export errors to `:4318` in logs are harmless).

## UI tests (Playwright)

Browser tests that go through the whole stack (web-app -> router -> services) live in `e2e/`.
They expect the stack above to be running and use a unique email per run, so they can be repeated against the same database.

```sh
make e2e-install   # once: npm deps + chromium
make e2e           # headless
make e2e-ui        # Playwright UI mode
```

`E2E_BASE_URL` overrides the target (default `http://localhost:8080`). New tests can be recorded with `cd e2e && npm run codegen`.

### CI

`.github/workflows/e2e.yml` runs the same setup on GitHub Actions: checks out the sibling repos next to `monorepo/`, runs `make init-configs`, starts the stack, serves web-app with vite and runs `make e2e` (`github` + html reporters, report uploaded as artifact on failure).
It runs nightly, on pushes/PRs to this repo and manually; manual runs accept a ref per service repo to test a feature branch.
Service repos can trigger it with a `repository_dispatch` event of type `service-updated` and payload `{"repo": "swarm-api", "ref": "<branch or sha>"}`.
