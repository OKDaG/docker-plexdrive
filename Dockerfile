FROM ubuntu:18.04
LABEL maintainer="wiserain"

ARG DEBIAN_FRONTEND="noninteractive"
ARG APT_MIRROR="archive.ubuntu.com"

ARG PLEXDRIVE_VERSION="5.1.0"
ARG TARGETARCH

# environment settings - s6
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_KEEP_ENV=1

# environment settings - container-level
ENV LANG=C.UTF-8
ENV PS1="\u@\h:\w\\$ "

# install packages
RUN \
 echo "**** apt source change for local build ****" && \
 sed -i "s/archive.ubuntu.com/\"$APT_MIRROR\"/g" /etc/apt/sources.list && \
 echo "**** install runtime packages ****" && \
 apt-get update && \
 apt-get install -y \
 	ca-certificates \
	fuse \
	tzdata \
 	unionfs-fuse && \
 update-ca-certificates && \
 apt-get install -y openssl && \
 sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf && \
 echo "**** install build packages ****" && \
 apt-get install -y \
 	curl \
 	unzip \
 	wget && \
 echo "**** add s6 overlay ****" && \
 OVERLAY_VERSION=$(curl -sX GET "https://api.github.com/repos/just-containers/s6-overlay/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
 OVERLAY_ARCH=$(if [ "$TARGETARCH" = "arm64" ]; then echo "aarch64"; elif [ "$TARGETARCH" = "arm" ]; then echo "armhf"; else echo "$TARGETARCH"; fi) && \
 curl -o /tmp/s6-overlay.tar.gz -L "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}.tar.gz" && \
 tar xfz  /tmp/s6-overlay.tar.gz -C / && \
 echo "**** add plexdrive ****" && \
 cd $(mktemp -d) && \
 PLEXDRIVE_ARCH=$(if [ "$TARGETARCH" = "arm" ]; then echo "arm7"; else echo "$TARGETARCH"; fi) && \
 wget https://github.com/plexdrive/plexdrive/releases/download/${PLEXDRIVE_VERSION}/plexdrive-linux-${PLEXDRIVE_ARCH} && \
 mv plexdrive-linux-${PLEXDRIVE_ARCH} /usr/bin/plexdrive && \
 chmod 777 /usr/bin/plexdrive && \
 echo "**** add mergerfs ****" && \
 MFS_VERSION=$(curl -sX GET "https://api.github.com/repos/trapexit/mergerfs/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
 MFS_ARCH=$(if [ "$TARGETARCH" = "arm" ]; then echo "armhf"; else echo "$TARGETARCH"; fi) && \
 MFS_DEB="mergerfs_${MFS_VERSION}.ubuntu-bionic_${MFS_ARCH}.deb" && \
 cd $(mktemp -d) && wget "https://github.com/trapexit/mergerfs/releases/download/${MFS_VERSION}/${MFS_DEB}" && \
 dpkg -i ${MFS_DEB} && \
 echo "**** create abc user ****" && \
 groupmod -g 1000 users && \
 useradd -u 911 -U -d /config -s /bin/false abc && \
 usermod -G users abc && \
 echo "**** cleanup ****" && \
 apt-get purge -y \
 	curl \
 	unzip \
 	wget && \
 apt-get clean autoclean && \
 apt-get autoremove -y && \
 rm -rf /tmp/* /var/lib/{apt,dpkg,cache,log}/

# add local files
COPY root/ /

# environment settings - pooling fs
ENV POOLING_FS "mergerfs"
ENV UFS_USER_OPTS "cow,direct_io,nonempty,auto_cache,sync_read"
ENV MFS_USER_OPTS "rw,async_read=false,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=partial,dropcacheonclose=true"

VOLUME /config /cache /log /cloud /data
WORKDIR /data

ENTRYPOINT ["/init"]
