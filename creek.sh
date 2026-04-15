#!/bin/bash
# Load your local secrets
source .env
rm -rf post-log.txt

# 1. Local Queue Notification
echo "[$(date +%T)] Sending Telegram Notification..."
curl -s -o /dev/null -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d chat_id="${TG_CHAT}" \
  -d parse_mode="HTML" \
  -d text="🛠 <b>Build Queued</b>"

# 2. Capture all output to log
TMP_LOG="creek-build-log.txt"
exec > >(tee -a "$TMP_LOG") 2>&1

# 3. The Crave Run Command
crave run --projectID 93 --no-patch -- '
  echo "============================================"
  echo "             Removing Sheets"
  echo "============================================"

  # List the specific folders that cause issues for creek
  remove=(
    out/soong
    out/target/product/creek
    device/xiaomi/creek
    vendor/xiaomi/creek
    vendor/xiaomi/miuicamera
    hardware/interfaces
    hardware/xiaomi
    out/target/product/creek
    hardware/qcom-caf/common
  )

  # Efficiently remove all of them
  for folder in "${remove[@]}"; do
      rm -rf "$folder"
      echo "    Cleaned: $folder"
  done

  # Remove local manifests
  rm -rf .repo/local_manifests/
  echo "=============================================="
  echo "               Cleaning Plates"
  echo "=============================================="

  # ROM source repo
  repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs
  echo "=============================================="
  echo "              Filling Buffets"
  echo "=============================================="

  # Clone local_manifests repository
  git clone https://github.com/nuruszama/local_manifest.git -b main .repo/local_manifests
  echo "=============================================="
  echo "               Filling Spices"
  echo "=============================================="

  # Sync the repositories
  /opt/crave/resync.sh
  echo "=============================================="
  echo "              Preparing Tables"
  echo "=============================================="

  # List the environment variables required for thr creek build
  exports=(
     "AIDL_FROZEN_REL=false"
     "SKIP_ABI_CHECKS=true"
     "SELINUX_IGNORE_NEVERALLOWS=true"
  )

  # Efficently export all of them
  for entry in "${exports[@]}"; do
      export "$entry"
      echo "     Exported: $entry"
  done

  # Set up build environment
  source build/envsetup.sh
  echo "=============================================="
  echo "             Placing Lunch Menu"
  echo "=============================================="

  # Lunch
  lunch lineage_creek-trunk_staging-userdebug

  # Make clean install
  make installclean

  echo "=============================================="
  echo "                Serving Lunch"
  echo "=============================================="
  mka bacon'

# 4. Capture the exit status immediately
EXIT_STATUS=$?
echo "EXIT_STATUS = $EXIT_STATUS"

echo "=============================================="
echo "             Winding up the Party"
echo "=============================================="

# 5. Post-Build Logic (Local Machine)
if [ $EXIT_STATUS -eq 0 ]; then
    # SUCCESS
    echo "Build Completed.. zip file ready to download......."
    curl -s -o /dev/null -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT" -d parse_mode="HTML" \
        -d text="✅ <b>Build Success!</b>%0A📦</code>"

elif [ $EXIT_STATUS -eq 130 ]; then
    # CANCELLED BY USER
    curl -s -o /dev/null -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT" -d parse_mode="HTML" \
        -d text="⚠️ <b>Build Cancelled:</b> User terminated the process manually."

else
    # FAILED DUE TO ERROR
    echo ">>Build Failed"
    curl -s -o /dev/null -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT" -d parse_mode="HTML" \
        -d text="<b>Build Failed (Error $EXIT_STATUS):</b> Check the log....."
fi

# 6. Stop logging and rename the file.
exec > /dev/tty 2>&1
sleep 2

POST_LOG="post-log.txt"
exec > >(tee -a "$POST_LOG") 2>&1

FIRST_LINE=$(head -n 1 "$TMP_LOG")
# Expecting: "Waiting for build id:266322 to start..."
BUILD_ID=$(echo "$FIRST_LINE" | grep -oP 'build id:\K[0-9]+')

if [ -n "$BUILD_ID" ]; then
    LOG_FILE="Build-$BUILD_ID-log.txt"
    mv "$TMP_LOG" "$LOG_FILE"
else
    LOG_FILE="$TMP_LOG"
    echo "⚠️ Could not extract build ID from log first line..."
fi

if [ -f "$LOG_FILE" ]; then
    echo "Uploading: $LOG_FILE"
    if curl -s -f -F chat_id="$TG_CHAT" -F message_thread_id="$TG_TOPIC" \
             -F document=@"$LOG_FILE" \
             "https://api.telegram.org/bot$TG_TOKEN/sendDocument"; then
        echo "Log Uploaded."
        rm -f "$LOG_FILE"
    else
        echo "Upload FAILED."
    fi
else
    echo "No log file found to upload."
fi
echo -e "\n\n.......Build Script Finished........."
