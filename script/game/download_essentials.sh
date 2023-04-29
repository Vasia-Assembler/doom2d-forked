#!/usr/bin/env bash

###########################################################################
#   fheroes2: https://github.com/ihhub/fheroes2                           #
#   Copyright (C) 2021 - 2023                                             #
#   Challenge9: https://github.com/Challenge9/doom2d-forever              #
#   Copyright (C) 2023                                                    #
#                                                                         #
#   This program is free software; you can redistribute it and/or modify  #
#   it under the terms of the GNU General Public License as published by  #
#   the Free Software Foundation; either version 2 of the License, or     #
#   (at your option) any later version.                                   #
#                                                                         #
#   This program is distributed in the hope that it will be useful,       #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#   GNU General Public License for more details.                          #
#                                                                         #
#   You should have received a copy of the GNU General Public License     #
#   along with this program; if not, write to the                         #
#   Free Software Foundation, Inc.,                                       #
#   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
###########################################################################

set -e -o pipefail


DOOMER="doomer.wad"
MAPPACK="doom2d.wad"
# EDITOR="editor.wad"
GAME="game.wad"
STANDART="standart.wad"
SHRSHADE="shrshade.wad"

BASE_URL="https://github.com/Challenge9/DF-Res/releases/download/v0.1.0" 
DOOMER_URL="${BASE_URL}/${DOOMER}"
MAPPACK_URL="${BASE_URL}/${MAPPACK}"
# EDITOR_URL="${BASE_URL}/${EDITOR}"
GAME_URL="${BASE_URL}/${GAME}"
STANDART_URL="${BASE_URL}/${STANDART}"
SHRSHADE_URL="${BASE_URL}/${SHRSHADE}"

function echo_red {
    echo -e "\033[0;31m$*\033[0m"
}

function echo_green {
    echo -e "\033[0;32m$*\033[0m"
}

function echo_stage {
    echo
    echo_green "$*"
    echo
}

echo_green "This script will download the game files for Doom 2D: Forever"
echo_green "It may take a few minutes, please wait..."

echo_stage "[1/3] determining the destination directory"

DEST_PATH="."

if [[ -n "$1" ]]; then
    DEST_PATH="$1"
elif [[ -f Doom2DF && -x Doom2DF ]]; then
    DEST_PATH="."
elif [[ -d ../../src ]]; then
    # Special hack for developers running this script from the source tree
    DEST_PATH="../../build/bin"
fi

echo_green "Destination directory: $DEST_PATH"

[[ ! -d $DEST_PATH ]] && mkdir -p "$DEST_PATH"

echo_stage "[2/3] downloading the game files"

cd "$DEST_PATH"

[[ ! -d ../wads ]] && mkdir wads
[[ ! -d ../maps ]] && mkdir maps
[[ ! -d ../maps/megawads ]] && mkdir -p maps/megawads
[[ ! -d ../data ]] && mkdir data
[[ ! -d ../data/models ]] && mkdir -p data/models

if [[ -n "$(command -v curl)" ]]; then
    curl -o "$MAPPACK" -L "$MAPPACK_URL"
    curl -o "$DOOMER" -L "$DOOMER_URL"
    curl -o "$GAME" -L "$GAME_URL"
    curl -o "$STANDART" -L "$STANDART_URL"
    curl -o "$SHRSHADE" -L "$SHRSHADE_URL"
else
    echo_red "Curl was not found in your system. Unable to download the game files. Installation aborted."
    exit 1
fi

echo_stage "[3/3] copying files"

cp $MAPPACK maps/
mv $MAPPACK maps/megawads/
mv $DOOMER data/models
mv $GAME data
mv $STANDART wads
mv $SHRSHADE wads