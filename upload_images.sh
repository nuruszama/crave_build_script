#!/bin/bash

# Load your local secrets
source .env

# --- CONFIGURATION ---
PRODUCT="creek"
OUT_DIR="out/target/product/$PRODUCT"
LOCAL_OUT_DIR="build_out"

# List of files we are looking for
FILES=(
    "boot.img"
    "init_boot.img"
    "vendor_boot.img"
    "recovery.img"
    "dtbo.img"
)

rm -rf $LOCAL_OUT_DIR
mkdir -p $LOCAL_OUT_DIR

echo "--- Pulling files from out folder ---"

# 1. Pull the static images
for FILE in "${FILES[@]}"; do
    if [ -f "$OUT_DIR/$FILE" ]; then
        echo "Found $FILE, pulling..."
        cp "$OUT_DIR/$FILE" "$LOCAL_OUT_DIR/"
    fi
done

# 2. Pull the Lineage ZIP (using wildcard)
cp $OUT_DIR/lineage-*.zip "$LOCAL_OUT_DIR/" 2>/dev/null

echo "--- Starting Telegram Upload ---"

# Function to upload to Telegram
upload_to_tg() {
    local file_path=$1
    echo "Uploading $(basename "$file_path")..."
    curl -F document=@"$file_path" \
         "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}" \
         -o /dev/null -s
}

# Iterate through files in devspace and upload
for ENTRY in "$LOCAL_OUT_DIR"/*; do
    if [ -f "$ENTRY" ]; then
        upload_to_tg "$ENTRY"
        echo "Done."
    fi
done

echo "All available files have been uploaded!"
