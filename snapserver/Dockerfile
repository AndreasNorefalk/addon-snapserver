ARG BUILD_FROM
FROM $BUILD_FROM

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3003
RUN \
    apk add --no-cache \
        pulseaudio alsa-plugins-pulse bash \
    && rm -fr \
        /tmp/*

# Install Bluetooth, Avahi, and supporting tools
RUN apk add --no-cache \
        bluez \
        pulseaudio \
        pulseaudio-bluez \
        pulseaudio-utils \
        dbus \
        avahi \
        avahi-tools

# Copy root filesystem with services
COPY rootfs /
RUN find /etc/s6-overlay/s6-rc.d -maxdepth 2 -type f \( -name run -o -name up \) -exec chmod +x {} \;

# Install Librespot (latest from edge/testing)
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ librespot

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
