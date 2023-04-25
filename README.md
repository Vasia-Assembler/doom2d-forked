# Doom 2D Forever
Doom 2D: Forever is a modern version of a Russian freeware doom game Doom 2D.

# Build
Requirements:
- FPC >= 3.0.4
- libenet >= 1.3.13

```
  mkdir -p ./game ./tmp
  git clone --recurse-submodules https://
  cd src/game
  fpc -B -dUSE_SDLMIXER -FE../../game -FU../../tmp Doom2DF.lpr
```

Windows binaries will require the appropriate DLLs (SDL2.dll, SDL2_mixer.dll or
FMODEx.dll, ENet.dll, miniupnpc.dll), unless you choose to static link them.

# Run
```
  ../../game/Doom2DF
```
