ROM_NAME="lineage"
DEVICE="creek"
RELEASE="trunk_staging"
BUILD_TYPE="userdebug"
BUILD_FLAVOUR="vanilla"
ANDROID_VERSION="v16 QPR2"
PROJECT_VERSION="LOS 23.2"
BRANCH="lineage-23.2"

# ================= TIMEZONE =================
echo "🕒 Switching system timezone to Gulf Standard Time"
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/Asia/Dubai /etc/localtime
echo "🕒 Current system time: $(date)"

# ================= JQ =================
if ! command -v jq &> /dev/null; then
    mkdir -p ~/bin
    curl -L -o ~/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64
    chmod +x ~/bin/jq
    export PATH=$HOME/bin:$PATH
fi

OUT_DIR="out/target/product/${DEVICE}"
START_TIME=$(date +%s)
BUILD_LOG="build.log"
ERROR_LOG="out/error.log"

# ================= TELEGRAM =================
tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=$1" >/dev/null
}

tg_upload() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=$1" >/dev/null
}

# ================= PIXELDRAIN =================
pixeldrain_upload() {
    local FILE="$1"

    if [ -f "$FILE" ]; then
        RESPONSE=$(curl -s -u ":$PIXELDRAIN" -F "file=@$FILE" https://pixeldrain.com/api/file)
        FILE_ID=$(echo "$RESPONSE" | jq -r '.id')

        if [[ "$FILE_ID" != "null" && -n "$FILE_ID" ]]; then
            echo "https://pixeldrain.com/u/$FILE_ID"
            return
        fi
    fi

    return 1
}

# ================= GOFILE =================
gofile_upload() {
    local FILE="$1"

    mapfile -t SERVERS < <(curl -s https://api.gofile.io/servers | jq -r '.data.servers[].name')

    for S in $(printf "%s\n" "${SERVERS[@]}" | shuf); do
        RESP=$(curl -s -F "file=@${FILE}" "https://${S}.gofile.io/uploadFile")
        LINK=$(echo "$RESP" | jq -r '.data.downloadPage // empty')

        if [ -n "$LINK" ]; then
            echo "$LINK"
            return
        fi
    done

    return 1
}

# ================= FAIL =================
on_fail() {
    tg_send "💥 *Bacon burned*
📜 Uploading logs…"

    LOG_MSG="╭─ 📜 LOGS"

    [ -f "$ERROR_LOG" ] && LOG_MSG="${LOG_MSG}
⋄ [Error Log]($(gofile_upload "$ERROR_LOG"))"

    [ -f "$BUILD_LOG" ] && LOG_MSG="${LOG_MSG}
⋄ [Build Log]($(gofile_upload "$BUILD_LOG"))"

    tg_upload "${LOG_MSG}"

    exit 1
}
