#!/bin/bash
GIT_ROOT=$(git rev-parse --show-toplevel)
CURRENT_DIR=$(pwd)

if [ "$GIT_ROOT" != "$CURRENT_DIR" ]; then
  echo "Current directory is not the root of the current git repository"
  exit 1
fi

cp dist/docker/trunk_release/Dockerfile .
sudo docker build -t df-trunk-release .
sudo docker run --name df-release df-trunk-release
sudo docker cp "df-release:/src/src/game/Doom2DF_release" build/bin/Doom2DF
sudo docker rm df-release
rm ./Dockerfile