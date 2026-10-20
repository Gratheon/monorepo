# Local dev stack. Repos are expected as siblings of this one (../swarm-api, ...).
# Every compose call shares COMPOSE_PROJECT_NAME so all services join gratheon_default.
export COMPOSE_PROJECT_NAME := "gratheon"

# Switches to the repo's .nvmrc Node. CI sets up Node itself and exports NVM_USE=true.
nvm_use := env("NVM_USE", ". $HOME/.nvm/nvm.sh && nvm use")
# CI exports E2E_INSTALL_ARGS=--with-deps to also install chromium system libraries
e2e_install_args := env("E2E_INSTALL_ARGS", "")

default:
    @just --list

# whole stack: storage, router, backend services, then web-app (vite, foreground)
start: start-storage start-router start-be start-fe

# stops web-app and all containers of the stack (data volumes are kept)
stop:
    -pkill -f 'web-app/node_modules/.*vite'
    -cd ../user-cycle && docker compose -f docker-compose.dev.yml down
    -cd ../image-splitter && docker compose -f docker-compose.dev.yml down
    -cd ../swarm-api && docker compose -f docker-compose.dev.yml down
    -cd ../graphql-router && docker compose -f docker-compose.dev.yml down
    -cd ../schema-registry && docker compose -f docker-compose.gratheon.yml down
    docker compose -f dev-env/docker-compose.yml down

# creates missing gitignored configs of sibling repos, existing ones are kept
init-configs:
    ./dev-env/init-configs.sh

# postgres + redis
start-storage:
    docker compose -f dev-env/docker-compose.yml up -d --wait

# graphql-router bind-mounts the repo over /app, so node_modules must exist on the host.
# schema-registry, then graphql-router
start-router:
    cd ../schema-registry && docker compose -f docker-compose.gratheon.yml up -d --build
    just _wait-http http://localhost:6001/
    cd ../graphql-router && ([ -d node_modules ] || npm ci) && docker compose -f docker-compose.dev.yml up -d --build

# swarm-api migrations run inside its container (DSN uses the docker hostname "postgres");
# jq runs on the host because the container image has none.
# Services push their schema to schema-registry on startup without retrying, and the registry
# rejects image-splitter's extensions of swarm-api types until swarm-api is registered.
# swarm-api registers before it starts listening, so wait for its port before the others.
# swarm-api (with migrations), image-splitter, user-cycle
start-be:
    cd ../swarm-api && docker compose -f docker-compose.dev.yml run --rm -e DSN="$(jq -r .db_dsn_migrate config/config.dev.json)" swarm-api sh -c 'go install github.com/pressly/goose/v3/cmd/goose@latest && $(go env GOPATH)/bin/goose -dir migrations postgres "$DSN" up'
    cd ../swarm-api && docker compose -f docker-compose.dev.yml up -d --build
    just _wait-http http://localhost:8100/
    cd ../image-splitter && docker compose -f docker-compose.dev.yml up -d --build
    cd ../user-cycle && docker compose -f docker-compose.dev.yml up -d --build

# web-app on http://localhost:8080 (foreground)
start-fe:
    cd ../web-app && {{nvm_use}} && pnpm i && pnpm dev

# once: npm deps + chromium
e2e-install:
    cd e2e && {{nvm_use}} && npm install && npx playwright install {{e2e_install_args}} chromium

# headless Playwright run against the running stack
e2e:
    cd e2e && {{nvm_use}} && npx playwright test

# Playwright UI mode
e2e-ui:
    cd e2e && {{nvm_use}} && npx playwright test --ui

# polls until the url answers with any HTTP status (swarm-api / is 403 without a token),
# gives up after ~5 min (no `timeout` on macOS)
[private]
_wait-http url:
    #!/usr/bin/env bash
    for _ in $(seq 150); do curl -s -o /dev/null '{{url}}' && exit 0; sleep 2; done
    echo '{{url}} not ready'; exit 1
