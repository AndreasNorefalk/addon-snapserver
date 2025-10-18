ARG BUILD_FROM=ghcr.io/hassio-addons/base:18.1.3
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG ALPINE_VERSION=3.22
ARG ALPINE_REPO_BASE=https://dl-cdn.alpinelinux.org/alpine

# hadolint ignore=DL3003
# Pin the Alpine repositories to avoid intermittent BAD archive errors from upstream mirrors.
RUN \
    for package in libcrypto3 libssl3 openssl; do \
        if grep -q "^${package}=" /etc/apk/world; then \
            sed -i "s/^${package}=.*/${package}/" /etc/apk/world; \
        fi; \
    done && \
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

# Disable the legacy services stage that conflicts with the base image by
# transforming the upstream s6 overlay helpers into no-ops.  Rely on a glob so
# the commands survive future overlay version bumps.
RUN set -euxo pipefail \
    && shopt -s nullglob \
    && legacy_services_up=(/package/admin/s6-overlay-*/etc/s6-rc/scripts/services-up) \
    && legacy_services_down=(/package/admin/s6-overlay-*/etc/s6-rc/scripts/services-down) \
    && [ "${#legacy_services_up[@]}" -gt 0 ] \
    && [ "${#legacy_services_down[@]}" -gt 0 ] \
    && for script in "${legacy_services_up[@]}"; do \
        cat <<'EOF' > "${script}"; \
#!/command/with-contenv sh

verbosity="${S6_VERBOSITY:-2}"
case "${verbosity}" in
    ''|*[!0-9]*)
        verbosity=2
        ;;
esac
if [ "${verbosity}" -ge 2 ]; then
    printf '%s\n' '[legacy-services] Skipping legacy service startup' >&2
fi
exit 0
EOF
        chmod 0755 "${script}"; \
    done \
    && for script in "${legacy_services_down[@]}"; do \
        cat <<'EOF' > "${script}"; \
#!/command/with-contenv sh

verbosity="${S6_VERBOSITY:-2}"
case "${verbosity}" in
    ''|*[!0-9]*)
        verbosity=2
        ;;
esac
if [ "${verbosity}" -ge 2 ]; then
    printf '%s\n' '[legacy-services] Skipping legacy service shutdown' >&2
fi
exit 0
EOF
        chmod 0755 "${script}"; \ 
    done

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
