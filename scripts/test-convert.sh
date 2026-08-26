#!/usr/bin/env bash
# Quick smoke test for the JODConverter REST endpoint.
# Usage: ./scripts/test-convert.sh <base-url> <source-file> <target-format> [api-key]
# Ex:    ./scripts/test-convert.sh http://localhost:8080 ./sample.docx pdf
# Ex:    ./scripts/test-convert.sh http://localhost:8080 ./sample.docx pdf my-secret-key
#
# The api-key argument (or the API_KEY env var) is only needed if the
# service was started with API_KEYS set -- see the README.

set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
SRC_FILE="${2:-}"
FORMAT="${3:-pdf}"
API_KEY="${4:-${API_KEY:-}}"

if [ -z "$SRC_FILE" ]; then
  echo "Usage: $0 <base-url> <source-file> <target-format> [api-key]" >&2
  exit 1
fi

OUT_FILE="converted.${FORMAT}"

CURL_ARGS=(-sS -f -F "data=@${SRC_FILE}")
if [ -n "$API_KEY" ]; then
  CURL_ARGS+=(-H "X-Api-Key: ${API_KEY}")
fi

echo "Converting ${SRC_FILE} to ${FORMAT} via ${BASE_URL} ..."
curl "${CURL_ARGS[@]}" \
  "${BASE_URL}/lool/convert-to/${FORMAT}" \
  -o "${OUT_FILE}"

echo "OK -> ${OUT_FILE}"
