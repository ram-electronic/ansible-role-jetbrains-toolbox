#!/usr/bin/env bash
# Run tests/run.sh locally in a fresh container per distribution (same as CI):
#
#   ./docker.sh                      all images below
#   ./docker.sh debian:13            only these
#
# Needs Docker. The role is mounted read-only; containers are removed afterwards.

set -uo pipefail

ROLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES=("$@")
(( ${#IMAGES[@]} )) || IMAGES=(debian:13 ubuntu:24.04 archlinux:latest)

failed=()
for image in "${IMAGES[@]}"; do
	printf '\n\e[1;34m==== %s\e[0m\n' "$image"
	docker run --rm -v "$ROLE_DIR:/role:ro" "$image" bash /role/tests/run.sh || failed+=("$image")
done

echo
if (( ${#failed[@]} )); then
	echo "Failed: ${failed[*]}"
	exit 1
fi
echo "All images passed: ${IMAGES[*]}"
