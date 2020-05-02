ARG DEBIAN_VER="stretch" 
FROM debian:${DEBIAN_VER}-slim as fetch-stage

############## fetch stage ##############

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# install fetch packages
RUN \
	set -ex \
	&& apt-get update \
	&& apt-get install -y \
	--no-install-recommends \
		ca-certificates \
		curl \
	\
# cleanup
	\
	&& rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch version file
RUN \
	set -ex \
	&& curl -o \
	/tmp/version.txt -L \
	"https://raw.githubusercontent.com/sparklyballs/versioning/master/version.txt"

# fetch source code
# hadolint ignore=SC1091
RUN \
	. /tmp/version.txt \
	&& set -ex \
	&& mkdir -p \
		/tmp/snapraid-src \
	&& curl -o \
	/tmp/snapraid.tar.gz -L \
	"https://github.com/amadvance/snapraid/releases/download/v${SNAPRAID_RELEASE}/snapraid-${SNAPRAID_RELEASE}.tar.gz" \
	&& tar xf \
	/tmp/snapraid.tar.gz -C \
	/tmp/snapraid-src --strip-components=1

FROM debian:${DEBIAN_VER}-slim as build-stage

############## build stage ##############

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# install build packages
RUN \
	set -ex \
	&& apt-get update \
	&& apt-get install -y \
	--no-install-recommends \
		checkinstall \
		g++ \
		gcc \
		make \
	\
# cleanup
	\
	&& rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

# copy artifacts from fetch stage
COPY --from=fetch-stage /tmp/snapraid-src /tmp/snapraid-src
COPY --from=fetch-stage /tmp/version.txt /tmp/version.txt
 
# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# set workdir 
WORKDIR /tmp/snapraid-src

# build package
# hadolint ignore=SC1091
RUN \
	source /tmp/version.txt \
	&& set -ex \
	&& ./configure \
	&& make \
	&& make check \
	&& checkinstall --pkgname snapraid- --pkgver "${SNAPRAID_RELEASE}" -Dy --install=no --nodoc
	
FROM debian:${DEBIAN_VER}-slim

############## package stage ##############

# copy fetch and build artifacts
COPY --from=build-stage /tmp/snapraid-src/*.deb /tmp/snapraid/
COPY --from=fetch-stage /tmp/version.txt /tmp/version.txt

# set workdir 
WORKDIR /tmp/snapraid

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# archive package
# hadolint ignore=SC1091
RUN \
	source /tmp/version.txt \
	&& set -ex \
	&& mkdir -p \
		/build \
	&& mv ./*.deb snapraid-"${SNAPRAID_RELEASE}".deb \
	&& tar -czvf /build/snapraid-"${SNAPRAID_RELEASE}".tar.gz \
		snapraid-"${SNAPRAID_RELEASE}".deb \
	&& chown -R 1000:1000 /build

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]
