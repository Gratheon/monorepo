# Local dev stack. Repos are expected as siblings of this one (../swarm-api, ...).
# Every compose call shares COMPOSE_PROJECT_NAME so all services join gratheon_default.
DC = COMPOSE_PROJECT_NAME=gratheon docker compose
NVM = . $$HOME/.nvm/nvm.sh

.PHONY: start start-storage start-router start-be start-fe stop e2e-install e2e e2e-ui

start: start-storage start-router start-be start-fe

start-storage:
	$(DC) -f dev-env/docker-compose.yml up -d --wait

start-router:
	cd ../schema-registry && $(DC) -f docker-compose.gratheon.yml up -d --build && sleep 10
	cd ../graphql-router && $(DC) -f docker-compose.dev.yml up -d --build

# swarm-api migrations run inside its container (DSN uses the docker hostname "postgres");
# jq runs on the host because the container image has none
start-be:
	cd ../swarm-api && $(DC) -f docker-compose.dev.yml run --rm -e DSN="$$(jq -r .db_dsn_migrate config/config.dev.json)" swarm-api sh -c 'go install github.com/pressly/goose/v3/cmd/goose@latest && $$(go env GOPATH)/bin/goose -dir migrations postgres "$$DSN" up'
	cd ../swarm-api && $(DC) -f docker-compose.dev.yml up -d --build
	cd ../image-splitter && $(DC) -f docker-compose.dev.yml up -d --build
	cd ../user-cycle && $(DC) -f docker-compose.dev.yml up -d --build

start-fe:
	cd ../web-app && $(NVM) && nvm use && pnpm i && pnpm dev

stop:
	-cd ../user-cycle && $(DC) -f docker-compose.dev.yml down
	-cd ../image-splitter && $(DC) -f docker-compose.dev.yml down
	-cd ../swarm-api && $(DC) -f docker-compose.dev.yml down
	-cd ../graphql-router && $(DC) -f docker-compose.dev.yml down
	-cd ../schema-registry && $(DC) -f docker-compose.gratheon.yml down
	$(DC) -f dev-env/docker-compose.yml down

e2e-install:
	cd e2e && $(NVM) && nvm use && npm install && npx playwright install chromium

e2e:
	cd e2e && $(NVM) && nvm use && npx playwright test

e2e-ui:
	cd e2e && $(NVM) && nvm use && npx playwright test --ui
