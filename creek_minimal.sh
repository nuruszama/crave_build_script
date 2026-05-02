#!/bin/bash
# Load your local secrets
source .env

# Local Queue Notification
echo "[$(date +%T)] Starting Minimal Boot Build..."
curl -s -o /dev/null -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d chat_id="${TG_CHAT}" \
  -d parse_mode="HTML" \
  -d text="🛠 <b>Attempting Minimal Boot Build</b>"

# The Crave Run Command
crave run --projectID 93 --no-patch -- '
  echo "============================================"
  echo "          Minimal Boot Creek Build"
  echo "============================================"
  
  # List the specific folders that cause issues for creek
  remove=(
    out/target/product/creek/lineage-*.zip
    device/xiaomi/*
    vendor/xiaomi/*
  )

  # Efficiently remove all of them
  for folder in "${remove[@]}"; do
      rm -rf "$folder"
      echo "    Cleaned: $folder"
  done

  # Remove local manifests
  rm -rf .repo/local_manifests/
  echo "============================================"
  echo "          Removing Local Manifest"
  echo "============================================"
  
  # ROM source repo
  repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs
  echo "============================================"
  echo "             LOS Repo initiated"
  echo "============================================"

  # Clone local_manifests repository
  git clone https://github.com/nuruszama/local_manifest.git -b minimal-boot .repo/local_manifests
  echo "============================================"
  echo "          Cloned local_manifest.xml"
  echo "============================================"

  # Sync
  /opt/crave/resync.sh
  echo "============================================"
  echo "             Repo Sync Completed"
  echo "============================================"

  # Env setup
  source build/envsetup.sh
  
  # Lunch
  lunch lineage_creek-trunk_staging-userdebug

  # Make clean install
  make installclean

  echo "============================================"
  echo "         initiating build sequence"
  echo "============================================"
  mka bootimage init_bootimage recoveryimage systemimage'
#  mka bacon'

EXIT_STATUS=$?
echo "EXIT_STATUS: $EXIT_STATUS"

echo "============================================"
echo "                Winding up"
echo "============================================"

if [ $EXIT_STATUS -eq 0 ]; then
    # SUCCESS
    echo "Build Completed.. Ready to test......."
    curl -s -o /dev/null -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT" -d parse_mode="HTML" \
        -d text="✅ <b>Build Completed..! Ready to test.......</b>%0A📦"

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
