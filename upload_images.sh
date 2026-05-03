#!/bin/bash

# Load your local secrets
source .env

# --- CONFIGURATION ---
PRODUCT="creek"
OUT_DIR="out/target/product/$PRODUCT"

echo "--- Checking files ---"

# 1. Capture the filenames only (not the full 'ls -l' details)
# We use 'basename' to keep the message clean
img_files=$(ls $OUT_DIR/*.img 2>/dev/null | xargs -n 1 basename)

# 2. Check if any files were actually found
if [ -z "$img_files" ]; then
    msg_text="<b>No image files found to upload.</b>"
else
    # Format the list with bullet points for Telegram
    file_list=$(echo "$img_files" | sed 's/^/• /')
    msg_text="<b>🚀 Uploading image files:</b>%0A${file_list}"
fi

# 3. Update available image files to telegram
curl -s -o /dev/null -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d chat_id="${TG_CHAT}" \
  -d parse_mode="HTML" \
  -d text="${msg_text}"

echo "--- Starting Telegram Upload ---"

# Function to upload to Telegram
upload_to_tg() {
    local file_path=$1
    local file_name=$(basename "$file_path")
    local FILE="$OUT_DIR/$file_name"
    
    echo "Uploading $FILE..."
    
    # Checking upload status
    if curl -s -f -F chat_id="$TG_CHAT" \
        -F document=@"$FILE" \
        "https://api.telegram.org/bot$TG_TOKEN/sendDocument"; then
        echo "Successfully uploaded $file_name"
    else
        echo "Failed to upload $file_name"
    fi
}

# 4. Iterate through files and upload
# We loop specifically for .img files to avoid uploading logs or random files
for IMG in "$OUT_DIR"/*.img; do
    if [ -f "$IMG" ]; then
        upload_to_tg "$IMG"
    fi
done

echo "All available files have been uploaded!"
