#!/usr/bin/env bash

###########################################################################
#   fheroes2: https://github.com/ihhub/fheroes2                           #
#   Copyright (C) 2021 - 2023                                             #
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

DF_URL="https://doom2d.org/doom2d_forever/latest/doom2df-win32.zip"
DF_ARCHIVE_NAME="doom2df-win32.zip"

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

echo_stage "[1/4] determining the destination directory"

DEST_PATH="."

if [[ -n "$1" ]]; then
    DEST_PATH="$1"
elif [[ -f Doom2DF && -x Doom2DF ]]; then
    DEST_PATH="."
elif [[ -d ../../src ]]; then
    # Special hack for developers running this script from the source tree
    DEST_PATH="../../build"
fi

echo_green "Destination directory: $DEST_PATH"

echo_stage "[2/4] downloading the game files"

[[ ! -d "$DEST_PATH/bin/files" ]] && mkdir -p "$DEST_PATH/bin/files"

cd "$DEST_PATH/bin/files"

if [[ -n "$(command -v wget)" ]]; then
    wget -O "$DF_ARCHIVE_NAME" "$DF_URL"
elif [[ -n "$(command -v curl)" ]]; then
    curl -o "$DF_ARCHIVE_NAME" -L "$DF_URL"
else
    echo_red "Neither wget nor curl were found in your system. Unable to download the game files. Installation aborted."
    exit 1
fi

echo_stage "[3/4] unpacking archives"

unzip -o "$DF_ARCHIVE_NAME"

echo_stage "[4/4] copying files"

[[ ! -d ../wads ]] && mkdir ../wads
[[ ! -d ../maps ]] && mkdir ../maps
[[ ! -d ../data ]] && mkdir ../data

cp -r wads/* ../wads
cp -r maps/* ../maps
cp -r data/* ../data