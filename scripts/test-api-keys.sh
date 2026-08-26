#!/usr/bin/env bash
# End-to-end test of the API_KEYS gate: builds the image, then spins up two
# containers in turn -- one with API_KEYS unset, one with two keys
# configured -- and checks every access-control case with curl.
#
# Usage: ./scripts/test-api-keys.sh [image-name] [host-port]
# Ex:    ./scripts/test-api-keys.sh jodconverter-railway 8080
#
# Requires Docker running locally. Does NOT use -e: individual failed
# checks are reported, not fatal, so the full matrix always runs.
set -uo pipefail

IMAGE_NAME="${1:-jodconverter-railway}"
HOST_PORT="${2:-8080}"
BASE_URL="http://localhost:${HOST_PORT}"
CONTAINER_NAME="jodconverter-apikey-test"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required on PATH to run this test." >&2
  exit 1
fi

SAMPLE_FILE="$(mktemp)"
echo "API key gate smoke test" > "${SAMPLE_FILE}"

PASS=0
FAIL=0

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  rm -f "${SAMPLE_FILE}"
}
trap cleanup EXIT

# Polls the always-open swagger-ui path until the container answers, since
# that endpoint is unaffected by API_KEYS either way.
wait_for_up() {
  local tries=60
  until [ "$(curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}/swagger-ui/index.html" 2>/dev/null)" = "200" ]; do
    tries=$((tries - 1))
    if [ "${tries}" -le 0 ]; then
      echo "Timed out waiting for ${BASE_URL} to come up." >&2
      docker logs "${CONTAINER_NAME}" 2>&1 | tail -n 40
      return 1
    fi
    sleep 2
  done
}

# start_container [-e VAR=val ...]
start_container() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker run -d --rm --name "${CONTAINER_NAME}" -p "${HOST_PORT}:8080" -e PORT=8080 "$@" "${IMAGE_NAME}" >/dev/null
  wait_for_up
}

# check <description> <method> <url> <expected-http-code> [extra curl args...]
check() {
  local desc="$1" method="$2" url="$3" expected="$4"
  shift 4
  local actual
  actual="$(curl -sS -o /dev/null -w '%{http_code}' -X "${method}" "$@" "${url}" 2>/dev/null)"
  if [ "${actual}" = "${expected}" ]; then
    echo "PASS  ${desc} (got ${actual})"
    PASS=$((PASS + 1))
  else
    echo "FAIL  ${desc} (expected ${expected}, got ${actual})"
    FAIL=$((FAIL + 1))
  fi
}

echo "Building ${IMAGE_NAME} ..."
docker build -t "${IMAGE_NAME}" . >/dev/null

echo
echo "=== Case set 1: API_KEYS unset -> access must be UNRESTRICTED ==="
start_container
check "conversion without any key"          POST "${BASE_URL}/lool/convert-to/pdf" 200 -F "data=@${SAMPLE_FILE};filename=sample.txt"
check "conversion with a random key anyway" POST "${BASE_URL}/lool/convert-to/pdf" 200 -F "data=@${SAMPLE_FILE};filename=sample.txt" -H "X-Api-Key: anything"
check "swagger-ui without a key"            GET  "${BASE_URL}/swagger-ui/index.html" 200
check "api-docs without a key"              GET  "${BASE_URL}/v3/api-docs" 200

echo
echo "=== Case set 2: API_KEYS=key-a,key-b -> access must be GATED ==="
start_container -e API_KEYS=key-a,key-b
check "conversion with no key at all"                POST "${BASE_URL}/lool/convert-to/pdf" 401 -F "data=@${SAMPLE_FILE};filename=sample.txt"
check "conversion with a wrong key (header)"         POST "${BASE_URL}/lool/convert-to/pdf" 401 -F "data=@${SAMPLE_FILE};filename=sample.txt" -H "X-Api-Key: nope"
check "conversion with a wrong key (query param)"    POST "${BASE_URL}/lool/convert-to/pdf?apiKey=nope" 401 -F "data=@${SAMPLE_FILE};filename=sample.txt"
check "conversion with the 1st valid key (header)"   POST "${BASE_URL}/lool/convert-to/pdf" 200 -F "data=@${SAMPLE_FILE};filename=sample.txt" -H "X-Api-Key: key-a"
check "conversion with the 2nd valid key (header)"   POST "${BASE_URL}/lool/convert-to/pdf" 200 -F "data=@${SAMPLE_FILE};filename=sample.txt" -H "X-Api-Key: key-b"
check "conversion with a valid key (query param)"    POST "${BASE_URL}/lool/convert-to/pdf?apiKey=key-a" 200 -F "data=@${SAMPLE_FILE};filename=sample.txt"
check "swagger-ui still open without a key"          GET  "${BASE_URL}/swagger-ui/index.html" 200
check "api-docs still open without a key"            GET  "${BASE_URL}/v3/api-docs" 200

echo
echo "=================================="
echo "PASS: ${PASS}   FAIL: ${FAIL}"
[ "${FAIL}" -eq 0 ]
