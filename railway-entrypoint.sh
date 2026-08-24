#!/usr/bin/env bash
# Railway injects a dynamic $PORT env var at runtime and expects the
# service to listen on it. Spring Boot maps the SERVER_PORT env var to
# the `server.port` property (relaxed binding), so we just forward it.
set -euo pipefail

if [ -n "${PORT:-}" ]; then
  export SERVER_PORT="${PORT}"
fi

# Delegate to the base jodconverter image entrypoint, keeping whatever
# CMD was inherited from it (e.g. --spring.config.additional-location=...).
exec /docker-entrypoint.sh "$@"
