# Doom 2D Forked

## Description
**Doom 2D: Forked** is a modern version of a Russian freeware doom game Doom 2D.

This open source multiplatform project, written from scratch, is designed to reproduce the original game with significant
improvements in gameplay, graphics and logic.

This is a fork of Doom 2D: Forever.

<p align="center">
    <img src="docs/images/screenshots/screenshot-superdm.png?raw=true" width="720">
</p>
<p align="center">
    <img src="docs/images/screenshots/screenshot-doom2d.png?raw=true" width="360"> <img src="docs/images/screenshots/screenshot-zadoomka.png?raw=true" width="360">
</p>

## Install

### Flatpak
Doom 2D: Forked has a Flatpak manifest, available at (https://github.com/Challenge9/org.doom2d.forked)

## Build
```
  git clone --recurse-submodules https://github.com/Challenge9/doom2d-forked
  cd doom2d-forked
  git submodule update --init
  mkdir -p ./build/bin ./build/tmp
  bash script/game/download_essentials.sh ./build/bin
  cd src/game
  fpc -B -dUSE_SDLMIXER -FE../../build/bin -FU../../build/tmp Doom2DF.lpr
  rm ../../build/tmp/*
```

Windows binaries will require the appropriate DLLs (SDL2.dll, SDL2_mixer.dll or
FMODEx.dll, ENet.dll, miniupnpc.dll), unless you choose to static link them.

**NOTE** Remember to clear the cache directory (`build/tmp` by default) after you've built the game!

## Run
- If you've followed build instructions above, `../../build/bin/Doom2DF`
- If Doom2DF is installed in the system PATH, `Doom2DF`


## Changes in comparison with Forever

- `renders_updated` experimental branch merged
- `renders_updated`: Allow playing on `master` servers from `renders_updated`
- `renders_updated`: Return preserve sky aspect ratio behavior from `main`
- New HUD
- Add flatpak build support
- `renders_updated`: Fade background when paused as `master` does
- `renders_updated`: Fix punch swing animation being played on the start of a round
- Always allow cheat in non-multiplayer games
- Centered camera (enabled by default)
- Add clientside player model and model's color override
- Remove player name length constraint
- Remove visual clutter in console
- Indicators are now drawn for all players, regardless of their team
- Fix building on FPC trunk
- Overhaul the repository structure
- `RAMBO` cheat also gives berserk
- `map` command without arguments now prints current map info
