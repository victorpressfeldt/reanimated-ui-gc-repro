#!/usr/bin/env bash
# Usage: scripts/use-versions.sh <sdk57|sdk58>
# Copies the chosen manifest and lockfile from versions/ to the project root
# and reinstalls. Run scripts/build.sh afterwards.
#   sdk57: Expo 57, React Native 0.86.0, Reanimated 4.5.1, Worklets 0.10.2
#   sdk58: Expo 58, React Native 0.88.1, Reanimated 4.8.0, Worklets 0.14.0
set -euo pipefail
cd "$(dirname "$0")/.."
SET=${1:?usage: use-versions.sh <sdk57|sdk58>}
[ -f "versions/$SET.package.json" ] || { echo "unknown version set: $SET"; exit 1; }
cp "versions/$SET.package.json" package.json
cp "versions/$SET.package-lock.json" package-lock.json
rm -rf node_modules
npm ci
