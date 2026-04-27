#!/bin/bash

Load env

source .env

echo "[$(date +%T)] Starting Minimal Boot Build..."

crave run --projectID 93 --no-patch -- '

echo "================================="
echo "     Minimal Creek Boot Build"
echo "================================="

Clean only what matters

rm -rf out/target/product/creek

Init repo

repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs

Local manifests

git clone https://github.com/nuruszama/local_manifest.git -b main .repo/local_manifests

Sync

/opt/crave/resync.sh

Env setup

source build/envsetup.sh

Lunch

lunch lineage_creek-trunk_staging-userdebug

Clean intermediates only

make installclean

echo "================================="
echo "      Building bootimage ONLY"
echo "================================="

🔥 ONLY build boot image

mka bootimage

'

EXIT_STATUS=$?

echo "Build finished with status: $EXIT_STATUS"

if [ $EXIT_STATUS -eq 0 ]; then
echo "✅ boot.img build SUCCESS"
else
echo "❌ build FAILED"
fi
