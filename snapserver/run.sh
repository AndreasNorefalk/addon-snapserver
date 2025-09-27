#!/command/with-contenv bashio

mkdir -p /share/snapfifo
mkdir -p /share/snapcast

# Ensure that the FIFO used by PulseAudio exists so Snapserver can attach to it.
if [[ ! -p /tmp/snapfifo ]]; then
    mkfifo /tmp/snapfifo
fi

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

exit "${PIPESTATUS[0]}"
