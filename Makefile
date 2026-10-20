# Local dev stack. Repos are expected as siblings of this one (../swarm-api, ...).
# Every compose call shares COMPOSE_PROJECT_NAME so all services join gratheon_default.
DC = COMPOSE_PROJECT_NAME=gratheon docker compose
# Switches to the repo's .nvmrc Node. CI sets up Node itself and overrides with NVM_USE=true.
NVM_USE ?= . $$HOME/.nvm/nvm.sh && nvm use
# $(call wait_http,url): poll until the url answers with any HTTP status (swarm-api / is 403
# without a token), give up after ~5 min (no `timeout` on macOS)
wait_http = i=0; until curl -s -o /dev/null $(1); do i=$$((i+1)); [ $$i -lt 150 ] || { echo "$(1) not ready"; exit 1; }; sleep 2; done

.PHONY: init-configs start start-storage start-router start-be start-fe stop e2e-install e2e e2e-ui

start: start-storage start-router start-be start-fe

# creates missing gitignored configs of sibling repos, existing ones are kept
init-configs:
	./dev-env/init-configs.sh

start-storage:
	$(DC) -f dev-env/docker-compose.yml up -d --wait

# graphql-router bind-mounts the repo over /app, so node_modules must exist on the host
start-router:
	cd ../schema-registry && $(DC) -f docker-compose.gratheon.yml up -d --build
	$(call wait_http,http://localhost:6001/)
	cd ../graphql-router && ([ -d node_modules ] || npm ci) && $(DC) -f docker-compose.dev.yml up -d --build

# swarm-api migrations run inside its container (DSN uses the docker hostname "postgres");
# jq runs on the host because the container image has none
# Services push their schema to schema-registry on startup without retrying, and the registry
# rejects image-splitter's extensions of swarm-api types until swarm-api is registered.
# swarm-api registers before it starts listening, so wait for its port before the others.
start-be:
	cd ../swarm-api && $(DC) -f docker-compose.dev.yml run --rm -e DSN="$$(jq -r .db_dsn_migrate config/config.dev.json)" swarm-api sh -c 'go install github.com/pressly/goose/v3/cmd/goose@latest && $$(go env GOPATH)/bin/goose -dir migrations postgres "$$DSN" up'
	cd ../swarm-api && $(DC) -f docker-compose.dev.yml up -d --build
	$(call wait_http,http://localhost:8100/)
	cd ../image-splitter && $(DC) -f docker-compose.dev.yml up -d --build
	cd ../user-cycle && $(DC) -f docker-compose.dev.yml up -d --build

start-fe:
	cd ../web-app && $(NVM_USE) && pnpm i && pnpm dev

stop:
	-cd ../user-cycle && $(DC) -f docker-compose.dev.yml down
	-cd ../image-splitter && $(DC) -f docker-compose.dev.yml down
	-cd ../swarm-api && $(DC) -f docker-compose.dev.yml down
	-cd ../graphql-router && $(DC) -f docker-compose.dev.yml down
	-cd ../schema-registry && $(DC) -f docker-compose.gratheon.yml down
	$(DC) -f dev-env/docker-compose.yml down

# CI passes E2E_INSTALL_ARGS=--with-deps to also install chromium system libraries
e2e-install:
	cd e2e && $(NVM_USE) && npm install && npx playwright install $(E2E_INSTALL_ARGS) chromium

e2e:
	cd e2e && $(NVM_USE) && npx playwright test

e2e-ui:
	cd e2e && $(NVM_USE) && npx playwright test --ui
