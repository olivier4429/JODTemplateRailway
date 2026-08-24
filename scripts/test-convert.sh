#!/usr/bin/env bash
# Quick smoke test for the JODConverter REST endpoint.
# Usage: ./scripts/test-convert.sh <base-url> <source-file> <target-format>
# Ex:    ./scripts/test-convert.sh http://localhost:8080 ./sample.docx pdf

set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
SRC_FILE="${2:-}"
FORMAT="${3:-pdf}"

if [ -z "$SRC_FILE" ]; then
  echo "Usage: $0 <base-url> <source-file> <target-format>" >&2
  exit 1
fi

OUT_FILE="converted.${FORMAT}"

echo "Converting ${SRC_FILE} to ${FORMAT} via ${BASE_URL} ..."
curl -sS -f \
  -F "data=@${SRC_FILE}" \
  "${BASE_URL}/lool/convert-to/${FORMAT}" \
  -o "${OUT_FILE}"

echo "OK -> ${OUT_FILE}"
