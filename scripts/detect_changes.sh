#!/bin/bash

echo "$(date --utc +%FT%TZ): Fetching remote repository..."

git fetch

UPSTREAM=${1:-'@{u}'}
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")

if [ $LOCAL = $REMOTE ]; then
  echo "$(date --utc +%FT%TZ): No changes detected in git"
elif [ $LOCAL = $BASE ]; then
  BUILD_VERSION=$(git rev-parse HEAD)
  echo "$(date --utc +%FT%TZ): Changes detected. Composing new version: $BUILD_VERSION"
  ./restart_if_changed.sh
elif [ $REMOTE = $BASE ]; then
  echo "$(date --utc +%FT%TZ): Local changes detected. Stashing..."
  git stash
  ./restart_if_changed.sh
else
  echo "$(date --utc +%FT%TZ): Git is diverged. This is unexpected..."
fi
