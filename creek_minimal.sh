#!/bin/bash

# Load env
source .env

echo "[$(date +%T)] Starting Minimal Boot Build..."

crave run --projectID 93 --no-patch -- '
  echo "================================="
  echo "     Minimal Creek Boot Build"
  echo "================================="
  
  # List the specific folders that cause issues for creek
  remove=(
    out/soong
    out/target/product/creek
    hardware/qcom-caf/*
    device/xiaomi/*
    vendor/xiaomi/*
    vendor/qcom/opensource/*
  )

  # Efficiently remove all of them
  for folder in "${remove[@]}"; do
      rm -rf "$folder"
      echo "    Cleaned: $folder"
  done

  # Remove local manifests
  rm -rf .repo/local_manifests/
  
  # ROM source repo
  repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs

  # Clone local_manifests repository
  git clone https://github.com/nuruszama/local_manifest.git -b minimal-boot .repo/local_manifests

  # Sync
  /opt/crave/resync.sh

  # Env setup
  source build/envsetup.sh

  # Lunch
  lunch lineage_creek-trunk_staging-userdebug

  # Clean intermediates only
  make installclean

  echo "================================="
  echo "      Building bootimage ONLY"
  echo "================================="

  # ONLY build boot image
  mka bootimage'

EXIT_STATUS=$?
echo "Build finished with status: $EXIT_STATUS"

if [ $EXIT_STATUS -eq 0 ]; then
    # SUCCESS
    crave run --projectID 93 -- 'curl -s -X POST "https://api.telegram.org/bot'"$TG_TOKEN"'/sendDocument" \
      -F chat_id="'"$TG_CHAT"'" \
      -F document=@"out/target/product/creek/boot.img '
    echo "Build Completed.. boot.img ready to test......."
    curl -s -o /dev/null -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT" -d parse_mode="HTML" \
        -d text="✅ <b>Build Success!</b>%0A📦"

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
        -d text="<b>Build Failed (Error $EXIT_STATUS)</b>"
fi
