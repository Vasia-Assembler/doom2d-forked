FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -y fpc

RUN apt-get install -y libsdl2-dev libsdl2-mixer-dev libenet-dev libopenal-dev libxmp-dev libvorbis-dev libmodplug-dev libmpg123-dev libopus-dev libopusfile-dev libgme-dev libminiupnpc-dev

RUN apt-get install -y libsdl2-2.0-0 libsdl2-mixer-2.0-0 libenet7 libopenal1 libxmp4 libvorbis0a libmodplug1 libmpg123-0 libopus0 libopusfile0 libgme0 libminiupnpc10

COPY ./src /src

WORKDIR /src

RUN cd /src/game && fpc -B -dUSE_OPENAL -dUSE_SDL2 -dUSE_VORBIS -dUSE_MODPLUG -dUSE_XMP -dUSE_MPG123 -dUSE_OPUS Doom2DF.lpr
