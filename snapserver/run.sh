#!/command/with-contenv bashio

mkdir -p /share/snapfifo
mkdir -p /share/snapcast

# Ensure that the FIFO used by PulseAudio exists so Snapserver can attach to it.
if [[ ! -p /tmp/snapfifo ]]; then
    mkfifo /tmp/snapfifo
fi

configure_audio_stack() {
    local attempt
    local controller
    local pa_ready=false

    export PULSE_RUNTIME_PATH="/var/run/pulse"
    export XDG_RUNTIME_DIR="/var/run/pulse"

    bashio::log.info "[Setup] Waiting for PulseAudio to become available"
    for attempt in $(seq 1 50); do
        if /command/s6-setuidgid pulse pactl info &>/dev/null; then
            pa_ready=true
            break
        fi
        sleep 0.2
    done

    if [[ "${pa_ready}" != true ]]; then
        bashio::log.warning "[Setup] PulseAudio did not become ready within the expected time"
    else
        if ! /command/s6-setuidgid pulse pactl list short sinks | grep -q "\\<bt_snapcast\\>"; then
            /command/s6-setuidgid pulse pactl load-module module-null-sink \\
                sink_name=bt_snapcast \\
                sink_properties=device.description="Bluetooth->Snapcast" || \\
                bashio::log.warning "[Setup] Failed to load module-null-sink"

            /command/s6-setuidgid pulse pactl load-module module-pipe-sink \\
                sink=bt_snapcast \\
                file=/tmp/snapfifo \\
                format=s16le \\
                rate=44100 \\
                channels=2 || \\
                bashio::log.warning "[Setup] Failed to load module-pipe-sink"
        fi

        if ! /command/s6-setuidgid pulse pactl set-default-sink bt_snapcast; then
            bashio::log.warning "[Setup] Unable to set bt_snapcast as the default PulseAudio sink"
        fi
    fi

    if ! command -v bluetoothctl >/dev/null 2>&1; then
        bashio::log.warning "[BT] bluetoothctl not found; skipping Bluetooth controller configuration"
        controller=""
    else
        bashio::log.info "[Setup] Waiting for Bluetooth controller"
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
            bashio::log.warning "[BT] Unable to communicate with bluetoothd; skipping controller configuration"
            controller=""
        fi
    fi

    if [[ -n "${controller}" ]]; then
        bashio::log.info "[BT] Found controller: ${controller}"
        if ! bluetoothctl --timeout 5 <<EOF
select ${controller}
power on
agent on
default-agent
pairable on
discoverable on
EOF
        then
            bashio::log.warning "[BT] Unable to configure Bluetooth controller ${controller}"
        fi
    else
        bashio::log.warning "[BT] No Bluetooth controller detected"
    fi
}

shopt -s extglob

declare streams
declare stream_bis
declare stream_ter
declare buffer
declare codec
declare muted
declare sampleformat
declare http
declare tcp
declare logging
declare threads
declare datadir

config=/etc/snapserver.conf

if ! bashio::fs.file_exists '/etc/snapserver.conf'; then
    touch /etc/snapserver.conf ||
        bashio::exit.nok "Could not create snapserver.conf file on filesystem"
fi
# Emit a clear marker so every start of the add-on is easy to spot in the
# Supervisor logs.
bashio::log.notice "---------- SnapServer add-on starting: $(date '+%Y-%m-%d %H:%M:%S') ----------"

bashio::log.info "Populating snapserver.conf..."

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
sanitize_streams "$(bashio::config 'streams')"

# Optional additional streams
if bashio::config.has_value 'stream_bis'; then
    sanitize_streams "$(bashio::config 'stream_bis')"
fi
if bashio::config.has_value 'stream_ter'; then
    sanitize_streams "$(bashio::config 'stream_ter')"
fi

# Buffer
buffer=$(bashio::config 'buffer')
echo "buffer = ${buffer}" >> "${config}"
# Codec
codec=$(bashio::config 'codec')
echo "codec = ${codec}" >> "${config}"
# Muted
muted=$(bashio::config 'send_to_muted')
echo "send_to_muted = ${muted}" >> "${config}"
# Sampleformat
sampleformat=$(bashio::config 'sampleformat')
echo "sampleformat = ${sampleformat}" >> "${config}"

# Http
http=$(bashio::config 'http_enabled')
echo "[http]" >> "${config}"
echo "enabled = ${http}" >> "${config}"
echo "bind_to_address = ::" >> "${config}"
# Datadir
datadir=$(bashio::config 'server_datadir')
echo "doc_root = ${datadir}" >> "${config}"
# TCP

echo "[tcp]" >> "${config}"
tcp=$(bashio::config 'tcp_enabled')
echo "enabled = ${tcp}" >> "${config}"

# Logging
echo "[logging]" >> "${config}"
logging=$(bashio::config 'logging_enabled')
echo "debug = ${logging}" >> "${config}"

# Threads
echo "[server]" >> "${config}"
threads=$(bashio::config 'server_threads')
echo "threads = ${threads}" >> "${config}"

# streaming client
echo "[streaming_client]" >> "${config}"
initial_volume=$(bashio::config 'initial_volume')
echo "initial_volume = ${initial_volume}" >> "${config}"

# Start SnapServer and post-process its output so the timestamps are refreshed on
# every log line.  Using a regular pipeline keeps the shell alive which allows us
# to capture the exit status cleanly via PIPESTATUS when the daemon stops.
configure_audio_stack &
setup_pid=$!

bashio::log.info "Starting SnapServer... (log reset)"

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
