#!/usr/bin/env bash
# Railway injects a dynamic $PORT env var at runtime and expects the
# service to listen on it. This template puts nginx in front of the
# jodconverter/Spring Boot app -- nginx is what actually binds $PORT, which
# is what makes the API_KEYS gate below possible (the Spring app itself
# always stays on a fixed internal port):
#
#   Railway --($PORT)--> nginx --($JODCONVERTER_APP_PORT, fixed)--> Spring Boot
set -euo pipefail

LISTEN_PORT="${PORT:-8080}"
BACKEND_PORT="${JODCONVERTER_APP_PORT:-8088}"

# Spring Boot's relaxed env-var binding maps SERVER_PORT -> server.port.
export SERVER_PORT="${BACKEND_PORT}"
export LISTEN_PORT BACKEND_PORT
export NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-25m}"

# --- API key gate ------------------------------------------------------
# API_KEYS: comma-separated list of keys allowed to call the API, e.g.
#   API_KEYS=key-for-team-a,key-for-team-b
# Callers must send one of them as either the `X-Api-Key` header or the
# `apiKey` query string parameter. Leave API_KEYS unset (the default) to
# keep the service open, as before.
#
# Swagger UI and the OpenAPI spec (/swagger-ui/*, /v3/api-docs) always stay
# reachable without a key -- see nginx.conf.template -- so they're still
# browsable and so Railway's own healthcheck (GET /swagger-ui/index.html,
# see railway.json) keeps working no matter how API_KEYS is set.
API_KEYS_MAP=/etc/nginx/conf.d/api_keys.map
AUTH_CONF=/etc/nginx/conf.d/auth.conf
mkdir -p /etc/nginx/conf.d
: > "${API_KEYS_MAP}"
: > "${AUTH_CONF}"

key_count=0
if [ -n "${API_KEYS:-}" ]; then
  IFS=',' read -ra _configured_keys <<< "${API_KEYS}"
  for raw_key in "${_configured_keys[@]}"; do
    # trim surrounding whitespace
    key="$(echo -n "${raw_key}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -n "${key}" ]; then
      escaped_key="${key//\"/\\\"}"
      echo "\"${escaped_key}\" 1;" >> "${API_KEYS_MAP}"
      key_count=$((key_count + 1))
    fi
  done
fi

if [ "${key_count}" -gt 0 ]; then
  echo 'if ($api_key_ok = 0) { return 401; }' > "${AUTH_CONF}"
  echo "railway-entrypoint: API key protection ENABLED (${key_count} key(s) configured)."
else
  echo "railway-entrypoint: API_KEYS not set (or empty) -- access is UNRESTRICTED."
fi

envsubst '${LISTEN_PORT} ${BACKEND_PORT} ${NGINX_CLIENT_MAX_BODY_SIZE}' \
  < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
nginx -t

# --- Start the jodconverter app and nginx side by side ------------------
# Delegate to the base jodconverter image entrypoint, keeping whatever
# CMD was inherited from it (e.g. --spring.config.additional-location=...).
/docker-entrypoint.sh "$@" &
app_pid=$!

nginx -g 'daemon off;' &
nginx_pid=$!

# If either process dies, tear down the other and exit -- Railway's restart
# policy (see railway.json) takes it from there.
trap 'kill "${app_pid}" "${nginx_pid}" 2>/dev/null || true' TERM INT

wait -n "${app_pid}" "${nginx_pid}"
exit_code=$?
kill "${app_pid}" "${nginx_pid}" 2>/dev/null || true
exit "${exit_code}"
