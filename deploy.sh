#!/usr/bin/env bash

echo "[$(date '+%F %T')] Deploy start"

#be very strict
#next line is for production use only
set -euo pipefail
#next line is for debugging only, comment in production
#set -euxo pipefail

useTag=""

helpFunction()
{
   echo "use this script to deploy the app, optionally specifying a tag"
   echo "Usage: $0 -t tag"
   echo -e "\t-t tag we want to deploy to production"
   echo -e "\t-h print this help"
   exit 1 # Exit script after printing help
}

#get some args
while getopts "t:h" opt
do
   case "$opt" in
      t ) useTag="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# use default values if not set
if [ -z "$useTag" ]; then
  useTag='dev'
  APP_DIR="/var/www/html/decade-matchmaking-service-portal_dev"
  BRANCH="main"
else
  APP_DIR="/var/www/html/decade-matchmaking-service-portal"
  BRANCH="$useTag"            # adjust if needed
fi

printf "deploying $BRANCH in $APP_DIR \n"

# --- CONFIG ---
REMOTE="origin"

PHP="/usr/bin/php"
COMPOSER="/usr/bin/composer"
NPM="/usr/bin/npm"
# --------------

# sanity check
[[ -d "$APP_DIR/.git" ]] || { echo "Not a git repo: $APP_DIR"; exit 1; }

cd "$APP_DIR"

# fetch latest refs
git fetch --prune "$REMOTE"
git checkout "$BRANCH"

LOCAL=$(git rev-parse @)
UPSTR=$(git rev-parse @{u})

if [[ "$LOCAL" == "$UPSTR" ]]; then
  echo "[$(date '+%F %T')] No changes detected — exiting."
  exit 0
else
  echo "[$(date '+%F %T')] Changes detected — resetting and pulling…"
fi

# clean + hard reset to ensure pristine working tree
git reset --hard
git clean -fdx
git pull --ff-only "$REMOTE" "$BRANCH"

# backend deps & migrations
if [ -z "$useTag" ]; then
  $COMPOSER install --prefer-dist --no-interaction --optimize-autoloader
else
  $COMPOSER install --no-dev --prefer-dist --no-interaction --optimize-autoloader
fi
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
