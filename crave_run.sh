#!/bin/bash

# set pipelined command flow
set -o pipefail

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!"
    exit 1
fi

# Load your local secrets
set -o allexport
source .env
set +o allexport

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

# ================= CONFIGS =================
curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_script/main/build_config.sh -o build_config.sh
source build_config.sh

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

# ================= BUILD START =================
tg_send "┌───────────────────┐
  📢      *Buildbot* initialized      📢
└───────────────────┘

      🧬 *${PROJECT_VERSION}*     🧩 *${DEVICE}*

 *Android Version:  ${ANDROID_VERSION}*
 *Build Type:  ${BUILD_TYPE}*
 *Release:  ${RELEASE}
 *Flavor:  ${BUILD_FLAVOUR}*

🌏 _$(date +"%d %b %Y %I:%M %p GST")_"

# ================= BUILD =================
echo ">>>> [STEP] Clean"
# List the specific folders that cause issues for creek
remove=(
    .repo/local_manifests
    hardware/qcom-caf/sm6225/*
    device/xiaomi/*
    vendor/xiaomi/*
    vendor/lineage-priv/keys
    vendor/qcom/opensource/*
)

# Efficiently remove all of them
for folder in "${remove[@]}"; do
    rm -rf "$folder"
    echo "    Cleaned: $folder"
done

echo ">>>> [STEP] Repo Init"
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs

echo ">>>> [STEP] Local Manifests"
git clone https://github.com/nuruszama/local_manifest.git -b main .repo/local_manifests

echo ">>>> [STEP] Repo Sync"
SYNC_START=$(date +%s)

if [ -f /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
else
    repo sync -c --force-sync --no-tags --no-clone-bundle -j$(nproc --all)
fi

rm -rf hardware/qcom-caf/common
git clone https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git -b lineage-23.2 hardware/qcom-caf/common

SYNC_END=$(date +%s)
SYNC_DIFF=$((SYNC_END - SYNC_START))

if [ $SYNC_DIFF -ge 3600 ]; then
    SYNC_TIME="$((SYNC_DIFF/3600))h $(((SYNC_DIFF%3600)/60))min"
else
    SYNC_TIME="$((SYNC_DIFF/60)) min"
fi
  
echo ">>>> [STEP] Set up build environment"
source build/envsetup.sh

echo ">>>> [STEP] Lunch"
lunch ${ROM_NAME}_${DEVICE}-${RELEASE}-${BUILD_TYPE}
export BUILD_USERNAME=nuruszama
export BUILD_HOSTNAME=arch
make installclean

tg_send "🔄 _Synchronization took ${SYNC_TIME}_
🔥 Baconing for *${DEVICE}*"

# ================= BUILD RUN =================
set -o pipefail
mka bacon 2>&1 | tee "$BUILD_LOG"

if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    on_fail
fi

if grep -q -E "ninja failed|failed to build some targets" "$BUILD_LOG"; then
    on_fail
fi

# ================= SUCCESS =================
END_TIME=$(date +%s)
DUR=$((END_TIME - START_TIME))

if [ $DUR -ge 3600 ]; then
    BUILD_TIME="$((DUR/3600))h $(((DUR%3600)/60))min"
else
    BUILD_TIME="$((DUR/60)) min"
fi

ROM_ZIP=$(ls -t ${OUT_DIR}/*.zip 2>/dev/null | head -n 1)

if [ -n "$ROM_ZIP" ]; then
    BUILD_ID=$(basename "$ROM_ZIP" .zip)
    ROM_SIZE=$(du -h "$ROM_ZIP" | awk '{print $1}')

    tg_send "┌───────────────────┐
    ✧ _Buildbot finished its job_ ✧
└───────────────────┘
🆔: \`${BUILD_ID}\`
📦 Size: *${ROM_SIZE}*
⏳ _Compilation took ${BUILD_TIME}_"

    tg_send "🚨 _Compiler gave up arguing. Uploading artifacts🥃…_"
fi

# ================= UPLOAD =================
echo ">>>> [STEP] Upload Artifacts"

HEADER_MSG="✧ ${ROM_NAME} Artifacts ✧
────────────────
🧩 ${DEVICE} | ${BUILD_TYPE} | ${ANDROID_VERSION}
🆔: \`${BUILD_ID}\`
"

UPLOAD_MSG=""
IMG_MSG=""

# ROM
if [ -n "$ROM_ZIP" ]; then
    GO_URL=$(gofile_upload "$ROM_ZIP")
    PD_URL=$(pixeldrain_upload "$ROM_ZIP")

    UPLOAD_MSG="${UPLOAD_MSG}
⋄ [GoFile](${GO_URL})
⋄ [PixelDrain](${PD_URL})
"
fi

# IMAGES
for IMG in boot.img vendor_boot.img init_boot.img super_empty.img recovery.img; do
    FILE="${OUT_DIR}/${IMG}"

    if [ -f "$FILE" ]; then
        GO_URL=$(gofile_upload "$FILE")

        IMG_MSG="${IMG_MSG}
⋄ [${IMG}](${GO_URL})"
    fi
done

# OTA
OTA_JSON="${OUT_DIR}/GMS/${DEVICE}.json"

if [ -f "$OTA_JSON" ]; then
    GO_URL=$(gofile_upload "$OTA_JSON")

    IMG_MSG="${IMG_MSG}

╭─ 📜 JSON
⋄ [OTA JSON](${GO_URL})"
fi

if [ -n "$IMG_MSG" ]; then
    IMG_MSG="╭─ 🧩 IMAGES${IMG_MSG}"
fi

FINAL_MESSAGE="${HEADER_MSG}${UPLOAD_MSG}${IMG_MSG}"

tg_upload "$FINAL_MESSAGE"

if [ -n "$ROM_ZIP" ]; then
    tg_send "🥀 _Artifacts released into the wild._"
fi
