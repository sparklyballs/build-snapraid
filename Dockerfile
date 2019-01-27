FROM debian:stretch

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# install build packages
RUN \
	apt-get update \
	&& apt-get install -y \
		checkinstall \
		curl \
		gcc \
		git \
		make

# get package version
RUN \
	SNAPRAID_RELEASE=$(curl -sX GET "https://api.github.com/repos/amadvance/snapraid/releases/latest" \
		| awk '/tag_name/{print $4;exit}' FS='[""]') \
	&& SNAPRAID_VERSION=${SNAPRAID_RELEASE#v} \
	&& echo "SNAPRAID_VERSION=${SNAPRAID_VERSION}" > /tmp/version.txt

# fetch source code
RUN \
	set -ex \
	&& . /tmp/version.txt \
	&& mkdir -p \
		/tmp/snapraid-${SNAPRAID_VERSION} \
	&& curl -o \
	snapraid-${SNAPRAID_VERSION}.tar.gz -L \
	"https://github.com/amadvance/snapraid/releases/download/v${SNAPRAID_VERSION}/snapraid-${SNAPRAID_VERSION}.tar.gz" \
	&& tar xf \
	snapraid-${SNAPRAID_VERSION}.tar.gz -C \
	/tmp/snapraid-${SNAPRAID_VERSION} --strip-components=1

# build and archive package
RUN \
	set -ex \
	&& . /tmp/version.txt \
	&& mkdir -p \
		/build \
	&& cd /tmp/snapraid-${SNAPRAID_VERSION} \
	&& ./configure \
	&& make \
	&& make check \
	&& checkinstall -Dy --install=no --nodoc \
	&& cp *.deb /build/snapraid-${SNAPRAID_VERSION}.deb

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]
