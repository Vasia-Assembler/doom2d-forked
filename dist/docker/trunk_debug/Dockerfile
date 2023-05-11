# syntax=docker/dockerfile:1
##
## Configuration
##
# set Ubuntu release version (latest, focal, bionic, ...)
ARG UBUNTU_VERSION=bionic
# set FPC version (format: d.d.d)
ARG FPC_VERSION=3.2.2
# set FPC trunk version (format: d.d.d)
ARG FPC_TRUNK_VERSION=3.3.1


##
## Create archive with FPC trunk by compiling source with latest official FPC
##
FROM freepascal/fpc:${FPC_VERSION}-focal-full as builder
WORKDIR /tmp
# docker buildx variables
ARG TARGETPLATFORM
ARG BUILDPLATFORM
# install git, clone sourcecode, compile FPC trunk and create single zip
RUN set -eux \
    && apt-get update \
    && apt-get install -y git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    #&& echo "Generating single archive installation for ${TARGETPLATFORM} on ${BUILDPLATFORM}." \
    # get sources from git repository
    # git describe does not work so fpc won't show the hash in output
    #&& git clone --branch main --single-branch --depth=1 https://gitlab.com/freepascal.org/fpc/source.git \
    && git clone --branch main https://gitlab.com/freepascal.org/fpc/source.git \
    && cd source* \
    # add git hash to fpc output
    && touch compiler/revision.inc \
    # compile and create single archive
    && make zipinstall -j$(nproc) \
    && mv fpc-*.tar.gz /opt/fpc-archive.tar.gz \
    # cleanup
    && rm -r /tmp/*


##
## Full installation of FPC trunk
##
# reuse previous argument value
ARG UBUNTU_VERSION
FROM ubuntu:${UBUNTU_VERSION} as fpc-full
WORKDIR /ws
# reuse previous argument value
ARG FPC_TRUNK_VERSION
# docker buildx variables
ARG TARGETPLATFORM
ARG BUILDPLATFORM
# copy created archive
COPY --from=builder /opt/fpc-archive.tar.gz /ws
# update system and install FPC
RUN set -eux \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y build-essential \
    #&& apt-get clean \
    #&& rm -rf /var/lib/apt/lists/* \
    #&& echo "Installing FPC trunk for ${TARGETPLATFORM} on ${BUILDPLATFORM}." \
    # extract compiled development version
    && tar -xzf fpc-archive.tar.gz \
    # install files
    && cp -r bin/* /usr/bin/ \
    && cp -r lib/* /usr/lib/ \
    && cp -r share /usr/share/doc/ \
    # generate config and symlink
    && fpcmkcfg -d basepath="/usr/lib/fpc/\$fpcversion" -o /etc/fpc.cfg \
    && ln -s $(find /usr/lib/fpc/${FPC_TRUNK_VERSION}/ -name ppc*) /usr/bin/$(basename $(find /usr/lib/fpc/${FPC_TRUNK_VERSION}/ -name ppc*)) \
    # cleanup
    && rm -r /ws/*


###
### Doom 2D: Forked compiled using FPC trunk, debug build
###

RUN apt-get install -y libsdl2-dev libsdl2-mixer-dev libenet-dev libopenal-dev libxmp-dev libvorbis-dev libmodplug-dev libmpg123-dev libopus-dev libopusfile-dev libgme-dev libminiupnpc-dev

RUN apt-get install -y libsdl2-2.0-0 libsdl2-mixer-2.0-0 libenet7 libopenal1 libxmp4 libvorbis0a libmodplug1 libmpg123-0 libopus0 libopusfile0 libgme0 libminiupnpc10

WORKDIR /src

COPY . .

WORKDIR /src/src/game

RUN fpc -B -a -O1 -dUSE_SDLMIXER -dUSE_SDL2 -dUSE_VORBIS -dUSE_MODPLUG -dUSE_XMP -dUSE_MPG123 -dUSE_OPUS -al Doom2DF.lpr -oDoom2DF_debug