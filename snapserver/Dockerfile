ARG BUILD_FROM=ghcr.io/hassio-addons/base:18.1.3
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG ALPINE_VERSION=3.22
ARG ALPINE_REPO_BASE=https://dl-cdn.alpinelinux.org/alpine

# hadolint ignore=DL3003
# Pin the Alpine repositories to avoid intermittent BAD archive errors from upstream mirrors.
RUN \
    ALPINE_MAIN_REPO="${ALPINE_REPO_BASE}/v${ALPINE_VERSION}/main" && \
    ALPINE_COMMUNITY_REPO="${ALPINE_REPO_BASE}/v${ALPINE_VERSION}/community" && \
    apk upgrade --no-cache \
        --repository="${ALPINE_MAIN_REPO}" \
        --repository="${ALPINE_COMMUNITY_REPO}" && \
    apk add --no-cache \
        --repository="${ALPINE_MAIN_REPO}" \
        --repository="${ALPINE_COMMUNITY_REPO}" \
        alsa-plugins-pulse \
        avahi \
        avahi-tools \
        bash \
        bluez \
        dbus \
        jq \
        openssl \
        pulseaudio \
        pulseaudio-bluez \
        pulseaudio-utils \
        su-exec \
        util-linux \
    && rm -fr \
        /tmp/*

# Copy root filesystem with services
COPY rootfs /
RUN find /etc/s6-overlay/s6-rc.d -maxdepth 2 -type f \( -name run -o -name up \) -exec chmod +x {} \;

# Install Librespot from source to avoid flaky edge packages
ARG LIBRESPOT_VERSION=0.7.1

RUN \
    ALPINE_MAIN_REPO="${ALPINE_REPO_BASE}/v${ALPINE_VERSION}/main" && \
    ALPINE_COMMUNITY_REPO="${ALPINE_REPO_BASE}/v${ALPINE_VERSION}/community" && \
    apk add --no-cache --virtual .build-deps \
        --repository="${ALPINE_MAIN_REPO}" \
        --repository="${ALPINE_COMMUNITY_REPO}" \
        alsa-lib-dev \
        build-base \
        cargo \
        clang \
        git \
        openssl-dev \
        pkgconf \
        pulseaudio-dev \
    && cargo install \
        --locked \
        --root /usr/local \
        --version "${LIBRESPOT_VERSION}" \
        librespot \
    && strip /usr/local/bin/librespot \
    && apk del .build-deps \
    && rm -rf \
        /root/.cache \
        /root/.cargo \
        /root/.rustup

# Install Snapcast
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community/ snapcast-server

# Install Snapweb
RUN \
    wget https://github.com/badaix/snapweb/releases/download/v0.8.0/snapweb.zip && \
    unzip -o snapweb.zip -d /usr/share/snapserver/snapweb/ && \
    rm snapweb.zip

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/init" ]
