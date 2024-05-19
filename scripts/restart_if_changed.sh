#!/usr/bin/env bash

git pull

BUILD_VERSION=$(git rev-parse HEAD)

echo "$(date --utc +%FT%TZ): Releasing new server version. $BUILD_VERSION"

echo "$(date --utc +%FT%TZ): Re-starting docker compose..."

# Start Docker Compose services in multiple directories

# Directory paths
NETWORKING="/home/hong/mini-pc-docker-compose-yml/home_server_docker/networking"
SERVER_MANAGEMENT="/home/hong/mini-pc-docker-compose-yml/home_server_docker/server_management"
TORRENTS="/home/hong/mini-pc-docker-compose-yml/home_server_docker/torrents"
MEDIA="/home/hong/mini-pc-docker-compose-yml/home_server_docker/media"
GENERAL="/home/hong/mini-pc-docker-compose-yml/home_server_docker/general"
# Add more directories if needed

# Function to check for changes and restart Docker Compose services
restart_if_changed() {
  local DIR=$1
  local COMPOSE_FILE="$DIR/docker-compose.yml"

  # Check if the docker-compose.yml file has changed
  if git diff --quiet HEAD^ HEAD -- "$COMPOSE_FILE"; then
    echo "$(date --utc +%FT%TZ): No changes detected in $COMPOSE_FILE. Skipping restart."
  else
    echo "$(date --utc +%FT%TZ): Changes detected in $COMPOSE_FILE. Restarting Docker Compose services..."
    (cd "$DIR" && docker compose restart)
  fi
}

# Check each directory and restart services if necessary
restart_if_changed "$NETWORKING"
restart_if_changed "$SERVER_MANAGEMENT"
restart_if_changed "$TORRENTS"
restart_if_changed "$MEDIA"
restart_if_changed "$GENERAL"

sleep 30
