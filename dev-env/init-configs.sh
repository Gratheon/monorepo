#!/usr/bin/env bash
# Creates the gitignored local config files of sibling repos (see README "Local config files").
# Existing files are never overwritten, so it is safe to run on an already configured machine.
# Used by `make init-configs` locally and by the e2e GitHub Actions workflow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEV_ENV="$ROOT/monorepo/dev-env"

create() {
	local target="$1"
	if [ -e "$target" ]; then
		echo "exists:  $target"
		return 1
	fi
	echo "created: $target"
}

# schema-registry: compose override pointing to the shared postgres/redis
if create "$ROOT/schema-registry/docker-compose.gratheon.yml"; then
	cp "$DEV_ENV/schema-registry/docker-compose.gratheon.yml" "$ROOT/schema-registry/docker-compose.gratheon.yml"
fi

# swarm-api: verifies JWTs issued by user-cycle, so it needs the same key.
# The dev key is the one committed in user-cycle config.default.ts unless JWT_KEY is given.
if create "$ROOT/swarm-api/config/config.dev.json"; then
	jwt_key="${JWT_KEY:-$(sed -n "s/^ *JWT_KEY: *'\([^']*\)'.*/\1/p" "$ROOT/user-cycle/src/config/config.default.ts")}"
	if [ -z "$jwt_key" ]; then
		echo "JWT_KEY not set and not found in user-cycle config.default.ts" >&2
		exit 1
	fi
	jq --arg key "$jwt_key" '.jwt_key = $key' "$ROOT/swarm-api/config/config.example.json" >"$ROOT/swarm-api/config/config.dev.json"
fi

# image-splitter, user-cycle: dev-env postgres runs without TLS
for repo in image-splitter user-cycle; do
	if create "$ROOT/$repo/src/config/config.dev.ts"; then
		cat >"$ROOT/$repo/src/config/config.dev.ts" <<'EOF'
// Local dev overrides (gitignored). Postgres runs in dev-env/docker-compose.yml without TLS.
import config from "./config.default";

export default {
  postgres: {
    ...config.postgres,
    ssl: process.env.DB_SSL || "disable",
  },
};
EOF
	fi
done
