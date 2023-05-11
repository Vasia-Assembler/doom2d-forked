#!/bin/bash
GIT_ROOT=$(git rev-parse --show-toplevel)
CURRENT_DIR=$(pwd)

if [ "$GIT_ROOT" != "$CURRENT_DIR" ]; then
  echo "Current directory is not the root of the current git repository"
  exit 1
fi

cp dist/docker/trunk_debug/Dockerfile .
sudo docker build -t df-trunk-debug .
sudo docker run --name df-debug df-trunk-debug
sudo docker cp "df-debug:/src/src/game/Doom2DF_debug" build/bin/Doom2DF
sudo docker rm df-debug
rm ./Dockerfile