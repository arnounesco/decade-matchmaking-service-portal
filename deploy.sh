#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
APP_DIR="/var/www/html/decade-matchmaking-service-portal"
BRANCH="main"            # adjust if needed
REMOTE="origin"

PHP="/usr/bin/php"
COMPOSER="/usr/bin/composer"
NPM="/usr/bin/npm"
# --------------

echo "[$(date '+%F %T')] Deploy start"

# sanity check
[[ -d "$APP_DIR/.git" ]] || { echo "Not a git repo: $APP_DIR"; exit 1; }

cd "$APP_DIR"

# fetch latest refs
git fetch --prune "$REMOTE"
git checkout "$BRANCH"

LOCAL=$(git rev-parse @)
UPSTR=$(git rev-parse @{u})

if [[ "$LOCAL" == "$UPSTR" ]]; then
  exit 0
fi

echo "[$(date '+%F %T')] Changes detected — resetting and pulling…"

# clean + hard reset to ensure pristine working tree
git reset --hard
git clean -fdx
git pull --ff-only "$REMOTE" "$BRANCH"

# backend deps & migrations
$COMPOSER install --no-dev --prefer-dist --no-interaction --optimize-autoloader
$PHP artisan migrate -n --force
$PHP artisan config:cache
$PHP artisan route:cache
$PHP artisan view:cache

# frontend deps & build
if [[ -f package-lock.json ]]; then
  $NPM ci --no-audit --no-fund
else
  $NPM install --no-audit --no-fund
fi

$NPM run build

echo "[$(date '+%F %T')] Deploy finished OK"
