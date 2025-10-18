#!/command/with-contenv bash
# shellcheck shell=bash

# Lightweight helpers to replace the Bashio dependency that disappeared from
# the base image.  The add-on configuration provided by the Supervisor is
# available as JSON in /data/options.json.
CONFIG_PATH="/data/options.json"

log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "${level}" "$*"
}

log_info() {
    log "INFO" "$@"
}

log_warning() {
    log "WARN" "$@"
}

log_notice() {
    log "NOTICE" "$@"
}

exit_nok() {
    log "ERROR" "$@"
    exit 1
}

config_get_raw() {
    local key="$1"
    if [[ ! -f "${CONFIG_PATH}" ]]; then
        return 1
    fi
    jq -er --arg key "${key}" '.[$key]' "${CONFIG_PATH}" 2>/dev/null
}

config_get() {
    local key="$1"
    local default_value="${2-}"
    local value

    if ! value=$(config_get_raw "${key}"); then
        if [[ $# -ge 2 ]]; then
            printf '%s' "${default_value}"
            return 0
        fi
        return 1
    fi

    # jq prints "null" for null values; treat that as missing.
    if [[ "${value}" == "null" ]]; then
        if [[ $# -ge 2 ]]; then
            printf '%s' "${default_value}"
            return 0
        fi
        return 1
    fi

    printf '%s' "${value}"
}

config_has_value() {
    local key="$1"
    local value
    if value=$(config_get_raw "${key}"); then
        [[ -n "${value}" && "${value}" != "null" ]]
    else
        return 1
    fi
}

find_system_helper() {
    local name="$1"
    local resolved=""

    if resolved=$(command -v "${name}" 2>/dev/null); then
        if [[ "${resolved}" != /command/* ]]; then
            printf '%s' "${resolved}"
            return 0
        fi
    fi

    local candidate
    for candidate in \
        "/usr/bin/${name}" \
        "/usr/sbin/${name}" \
        "/bin/${name}" \
        "/sbin/${name}"; do
        if [[ -x "${candidate}" ]]; then
            printf '%s' "${candidate}"
            return 0
        fi
    done

    return 1
}

run_as_pulse() {
    local helper

    if helper=$(find_system_helper setpriv); then
        "${helper}" --reuid pulse --regid pulse --init-groups "$@"
        return $?
    fi

    if helper=$(find_system_helper runuser); then
        "${helper}" -u pulse -- "$@"
        return $?
    fi

    log_warning "[Setup] Unable to drop privileges; running command as root: $1"
    "$@"
}

if [[ ! -f "${CONFIG_PATH}" ]]; then
    exit_nok "Configuration file ${CONFIG_PATH} not found"
fi

mkdir -p /share/snapfifo
mkdir -p /share/snapcast

# Ensure that the FIFO used by PulseAudio exists so Snapserver can attach to it.
if [[ ! -p /tmp/snapfifo ]]; then
    mkfifo -m 0660 /tmp/snapfifo
else
    chmod 0660 /tmp/snapfifo || true
fi
chown pulse:pulse /tmp/snapfifo 2>/dev/null || true

# Export environment variables that make PulseAudio and pactl behave in a
# predictable headless manner.
mkdir -p /var/run/pulse/.config/pulse
export PULSE_RUNTIME_PATH="/var/run/pulse"
export XDG_RUNTIME_DIR="/var/run/pulse"
export HOME="/var/run/pulse"
export XDG_CONFIG_HOME="/var/run/pulse/.config"
export PULSE_COOKIE="/var/run/pulse/.config/pulse/cookie"
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/var/run/dbus/system_bus_socket"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SYSTEM_BUS_ADDRESS}"

configure_audio_stack() {
    local attempt
    local controller
    local pa_ready=false

    log_info "[Setup] Waiting for PulseAudio to become available"
    for attempt in $(seq 1 50); do
        if run_as_pulse pactl info &>/dev/null; then
            pa_ready=true
            break
        fi
        sleep 0.2
    done

    if [[ "${pa_ready}" != true ]]; then
        log_warning "[Setup] PulseAudio did not become ready within the expected time"
    else
        if ! run_as_pulse pactl list short sinks | grep -q "\<bt_snapcast\>"; then
            run_as_pulse pactl load-module module-pipe-sink \
                sink_name=bt_snapcast \
                sink_properties=device.description="Bluetooth->Snapcast" \
                file=/tmp/snapfifo \
                format=s16le \
                rate=44100 \
                channels=2 || \
                log_warning "[Setup] Failed to load module-pipe-sink"
        fi

        if ! run_as_pulse pactl set-default-sink bt_snapcast; then
            log_warning "[Setup] Unable to set bt_snapcast as the default PulseAudio sink"
        fi
    fi

    if ! command -v bluetoothctl >/dev/null 2>&1; then
        log_warning "[BT] bluetoothctl not found; skipping Bluetooth controller configuration"
        controller=""
    else
        log_info "[Setup] Waiting for Bluetooth controller"
        controller=""
        local bluetooth_ready=false
        local bluetooth_output=""

        for attempt in $(seq 1 40); do
            if bluetooth_output=$(bluetoothctl --timeout 1 list 2>/dev/null); then
                bluetooth_ready=true
                controller=$(awk 'NR==1 {print $2}' <<<"${bluetooth_output}")
                [[ -n "${controller}" ]] && break
            fi
            sleep 0.5
        done

        if [[ "${bluetooth_ready}" != true ]]; then
            log_warning "[BT] Unable to communicate with bluetoothd; skipping controller configuration"
            controller=""
        fi
    fi

    if [[ -n "${controller}" ]]; then
        log_info "[BT] Found controller: ${controller}"
        if ! bluetoothctl --timeout 5 <<EOF
select ${controller}
power on
agent on
default-agent
pairable on
discoverable on
EOF
        then
            log_warning "[BT] Unable to configure Bluetooth controller ${controller}"
        fi
    else
        log_warning "[BT] No Bluetooth controller detected"
    fi
}


shopt -s extglob

config=/etc/snapserver.conf

if [[ ! -f '/etc/snapserver.conf' ]]; then
    touch /etc/snapserver.conf ||
        exit_nok "Could not create snapserver.conf file on filesystem"
fi
# Emit a clear marker so every start of the add-on is easy to spot in the
# Supervisor logs.
log_notice "---------- SnapServer add-on starting: $(date '+%Y-%m-%d %H:%M:%S') ----------"

log_info "Populating snapserver.conf..."

echo "[stream]" > "${config}"

sanitize_streams() {
    local raw_streams="$1"
    local stream

    while IFS= read -r stream || [[ -n "${stream}" ]]; do
        # Trim leading/trailing whitespace
        stream="${stream##+([[:space:]])}"
        stream="${stream%%+([[:space:]])}"

        [[ -z "${stream}" ]] && continue

        if [[ "${stream,,}" == null ]]; then
            continue
        fi

        if [[ "${stream}" != source\ =* ]]; then
            stream="source = ${stream}"
        fi

        echo "${stream}" >> "${config}"
    done <<< "${raw_streams}"
}

# Streams
streams_value=$(config_get 'streams') || exit_nok "Required option 'streams' is missing"
sanitize_streams "${streams_value}"

# Optional additional streams
if config_has_value 'stream_bis'; then
    stream_bis_value=$(config_get 'stream_bis')
    sanitize_streams "${stream_bis_value}"
fi
if config_has_value 'stream_ter'; then
    stream_ter_value=$(config_get 'stream_ter')
    sanitize_streams "${stream_ter_value}"
fi

# Buffer
buffer=$(config_get 'buffer' '')
echo "buffer = ${buffer}" >> "${config}"
# Codec
codec=$(config_get 'codec' '')
echo "codec = ${codec}" >> "${config}"
# Muted
muted=$(config_get 'send_to_muted' '')
echo "send_to_muted = ${muted}" >> "${config}"
# Sampleformat
sampleformat=$(config_get 'sampleformat' '')
echo "sampleformat = ${sampleformat}" >> "${config}"

# Http
http=$(config_get 'http_enabled' '')
echo "[http]" >> "${config}"
echo "enabled = ${http}" >> "${config}"
echo "bind_to_address = ::" >> "${config}"
# Datadir
datadir=$(config_get 'server_datadir' '')
echo "doc_root = ${datadir}" >> "${config}"
# TCP

echo "[tcp]" >> "${config}"
tcp=$(config_get 'tcp_enabled' '')
echo "enabled = ${tcp}" >> "${config}"

# Logging
echo "[logging]" >> "${config}"
logging=$(config_get 'logging_enabled' '')
echo "debug = ${logging}" >> "${config}"

# Threads
echo "[server]" >> "${config}"
threads=$(config_get 'server_threads' '')
echo "threads = ${threads}" >> "${config}"

# streaming client
echo "[streaming_client]" >> "${config}"
initial_volume=$(config_get 'initial_volume' '')
echo "initial_volume = ${initial_volume}" >> "${config}"

# Start SnapServer and post-process its output so the timestamps are refreshed on
# every log line.  Using a regular pipeline keeps the shell alive which allows us
# to capture the exit status cleanly via PIPESTATUS when the daemon stops.
configure_audio_stack &
setup_pid=$!

log_info "Starting SnapServer... (log reset)"

snapserver 2>&1 | awk -v dts="$(date '+%Y-%m-%d %H:%M:%S')" '
  BEGIN { print "[" dts "] [LOG RESET] ------------------------" }
  {
    cmd="date +\"%Y-%m-%d %H:%M:%S\""
    cmd | getline t
    close(cmd)
    print "[" t "] " $0
    fflush()
  }'

snapserver_exit=${PIPESTATUS[0]}
wait "${setup_pid}" 2>/dev/null || true

exit "${snapserver_exit}"
