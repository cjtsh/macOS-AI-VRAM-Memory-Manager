#!/bin/bash
set -uo pipefail

TARGET="${1:?usage: staple-with-retries.sh <app-or-dmg-path>}"
MAX_ATTEMPTS=5

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "Stapling and validating $TARGET (attempt $attempt/$MAX_ATTEMPTS)"
  if xcrun stapler staple "$TARGET" && xcrun stapler validate "$TARGET"; then
    exit 0
  fi
  if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    delay=$((attempt * 10))
    echo "Apple ticket service operation failed; retrying in ${delay}s." >&2
    sleep "$delay"
  fi
done

echo "Unable to staple and validate Apple's notarization ticket for $TARGET." >&2
exit 1
