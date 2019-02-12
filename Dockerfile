ARG DEBIAN_VERSION="stretch" 
FROM debian:$DEBIAN_VERSION as fetch-stage

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
		jq \
	\
# cleanup
	\
	&& rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch source code
RUN \
	set -ex \
	&& mkdir -p \
		/tmp/snapraid-src \
	&& SNAPRAID_RELEASE=$(curl -sX GET "https://api.github.com/repos/amadvance/snapraid/releases/latest" \
		| jq -r .tag_name) \
	&& SNAPRAID_VERSION="${SNAPRAID_RELEASE#v}" \
	&& curl -o \
	snapraid.tar.gz -L \
	"https://github.com/amadvance/snapraid/releases/download/v${SNAPRAID_VERSION}/snapraid-${SNAPRAID_VERSION}.tar.gz" \
	&& tar xf \
	snapraid.tar.gz -C \
	/tmp/snapraid-src --strip-components=1 \
	&& echo "SNAPRAID_VERSION=${SNAPRAID_VERSION}" > /tmp/version.txt

FROM debian:$DEBIAN_VERSION as build-stage

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
	&& checkinstall --pkgname snapraid- --pkgver "${SNAPRAID_VERSION}" -Dy --install=no --nodoc
	
FROM debian:$DEBIAN_VERSION

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
	&& mv ./*.deb snapraid-"${SNAPRAID_VERSION}".deb \
	&& tar -czvf /build/snapraid-"${SNAPRAID_VERSION}".tar.gz \
		snapraid-"${SNAPRAID_VERSION}".deb

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]
